#!/usr/bin/env bash
# gemini-supervisor.sh — Robust Gemini CLI wrapper for the dispatch skill
#
# Wraps the Gemini CLI with smart retry, error classification, model fallback,
# circuit breaker, and structured logging. Preserves CLI agent capability
# (cd / read files / execute SOP) while fixing CLI's broken retry layer.
#
# Background: Gemini CLI has known retry/fallback bugs (Issues #9248, #2140,
# #10722, #18030). This wrapper applies the official-recommended exponential
# backoff + jitter + structured error parsing pattern that CLI lacks.
#
# Usage:
#   gemini-supervisor.sh "your prompt"
#   gemini-supervisor.sh --cwd /path "prompt"
#   gemini-supervisor.sh --model gemini-2.5-pro "prompt"
#   echo "prompt" | gemini-supervisor.sh --stdin
#
# Exit: 0 = success (output on stdout), 1 = all fallbacks exhausted

set -uo pipefail

# ── Config ───────────────────────────────────────────────────────────────

# Fallback chain: preview pro → GA pro (early) → preview flash → GA flash
# Rationale: when preview pool is congested, preview flash may share the same
# pool and not escape. GA models go through Vertex AI dedicated capacity.
FALLBACK_CHAIN=(
  "gemini-3.1-pro-preview"
  "gemini-2.5-pro"
  "gemini-3.1-flash-preview"
  "gemini-2.5-flash"
)

# Per-model attempt cap (short-burst retries before falling back)
MODEL_ATTEMPT_CAP="${GEMINI_MODEL_ATTEMPTS:-2}"

# Global attempt budget across all models
GLOBAL_ATTEMPT_BUDGET="${GEMINI_GLOBAL_BUDGET:-6}"

# Per-model hard timeout (seconds)
MODEL_HARD_TIMEOUT="${GEMINI_MODEL_TIMEOUT:-600}"

# Circuit breaker: cool-down a model after N consecutive failures
CIRCUIT_FAILURE_THRESHOLD="${GEMINI_CIRCUIT_THRESHOLD:-3}"
CIRCUIT_COOLDOWN_SECS="${GEMINI_CIRCUIT_COOLDOWN:-1800}"  # 30 min

# State files
STATE_DIR="$HOME/.cache/dispatch"
STATE_FILE="$STATE_DIR/gemini-state.json"
LOG_FILE="$STATE_DIR/gemini.log"

mkdir -p "$STATE_DIR"
[[ -f "$STATE_FILE" ]] || echo '{}' > "$STATE_FILE"

# ── Arg parsing ──────────────────────────────────────────────────────────

PROMPT=""
CWD="$(pwd)"
USER_MODEL=""
USE_STDIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd) CWD="$2"; shift 2 ;;
    --model|-m) USER_MODEL="$2"; shift 2 ;;
    --stdin) USE_STDIN=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) PROMPT="$1"; shift ;;
  esac
done

if [[ "$USE_STDIN" -eq 1 ]]; then
  PROMPT=$(cat)
fi

if [[ -z "$PROMPT" ]]; then
  echo "[gemini-supervisor] error: empty prompt" >&2
  exit 1
fi

# If user pinned a specific model, use only that (no fallback)
if [[ -n "$USER_MODEL" ]]; then
  FALLBACK_CHAIN=("$USER_MODEL")
fi

# ── Logging ──────────────────────────────────────────────────────────────

log_event() {
  local model="$1" attempt="$2" status="$3" latency_ms="$4" extra="$5"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{"ts":"%s","model":"%s","attempt":%d,"status":"%s","latency_ms":%d,"extra":%s}\n' \
    "$ts" "$model" "$attempt" "$status" "$latency_ms" "${extra:-null}" \
    >> "$LOG_FILE"
}

stderr() { echo "[gemini-supervisor] $*" >&2; }

# ── Circuit breaker ──────────────────────────────────────────────────────

# Returns 0 if model is OPEN (cooldown), 1 if CLOSED (ok to call).
circuit_is_open() {
  local model="$1"
  local now opened_at fails
  now=$(date +%s)
  opened_at=$(jq -r --arg m "$model" '.[$m].opened_at // 0' "$STATE_FILE" 2>/dev/null || echo 0)
  if [[ "$opened_at" -gt 0 ]] && (( now - opened_at < CIRCUIT_COOLDOWN_SECS )); then
    return 0  # OPEN
  fi
  # Auto-close if cooldown elapsed
  if [[ "$opened_at" -gt 0 ]]; then
    update_state "$model" '{"opened_at": 0, "consecutive_failures": 0}'
  fi
  return 1  # CLOSED
}

update_state() {
  local model="$1" patch="$2"
  local tmp
  tmp=$(mktemp)
  jq --arg m "$model" --argjson p "$patch" '.[$m] = ((.[$m] // {}) + $p)' \
    "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

record_failure() {
  local model="$1"
  local fails now
  fails=$(jq -r --arg m "$model" '.[$m].consecutive_failures // 0' "$STATE_FILE")
  fails=$((fails + 1))
  if (( fails >= CIRCUIT_FAILURE_THRESHOLD )); then
    now=$(date +%s)
    update_state "$model" "{\"consecutive_failures\": $fails, \"opened_at\": $now}"
    stderr "circuit OPEN for $model (cooldown ${CIRCUIT_COOLDOWN_SECS}s)"
  else
    update_state "$model" "{\"consecutive_failures\": $fails}"
  fi
}

record_success() {
  local model="$1"
  update_state "$model" '{"consecutive_failures": 0, "opened_at": 0}'
}

# ── Error classification ────────────────────────────────────────────────

# Classify Gemini error: short_burst | quota_exhausted | model_capacity | other
# Reads combined stdout+stderr; returns classification on stdout.
classify_error() {
  local output="$1"

  # Daily quota / project limit exhaustion (don't retry same model)
  if echo "$output" | grep -qE '("limit"[[:space:]]*:[[:space:]]*0|QuotaFailure|RPD|exceeded.*daily|Quota exceeded)'; then
    echo "quota_exhausted"
    return
  fi

  # Server-side model capacity (preview pool full) — short backoff may help
  if echo "$output" | grep -qE '(MODEL_CAPACITY_EXHAUSTED|No capacity available|503|UNAVAILABLE)'; then
    echo "model_capacity"
    return
  fi

  # Short-burst rate limit (RPM) — backoff usually works
  if echo "$output" | grep -qE '(429|RESOURCE_EXHAUSTED|rateLimitExceeded|Too Many Requests)'; then
    echo "short_burst"
    return
  fi

  # Auth / config / network — won't fix with retry
  if echo "$output" | grep -qE '(401|403|UNAUTHENTICATED|PERMISSION_DENIED|invalid api key|reauthent)'; then
    echo "auth_error"
    return
  fi

  echo "other"
}

# Exponential backoff with jitter, capped at 30s.
# Args: attempt_number (1-based)
backoff_secs() {
  local attempt="$1"
  local base=$((2 ** (attempt - 1)))      # 1, 2, 4, 8, 16
  (( base > 16 )) && base=16
  local jitter=$((RANDOM % 500))           # 0-499 ms
  # Print as integer seconds (drop ms for sleep)
  echo "$base.${jitter}"
}

# ── Single attempt with timeout ─────────────────────────────────────────

# Args: model
# Stdout: gemini output (or empty on failure)
# Stderr: gemini error stream
# Returns: 0 success, non-zero on failure
try_model() {
  local model="$1"
  local out_file err_file rc
  out_file=$(mktemp)
  err_file=$(mktemp)

  # Use perl as portable timeout (no gtimeout on macOS by default).
  # SIGTERM the gemini process if it hangs past MODEL_HARD_TIMEOUT.
  (
    cd "$CWD" || exit 1
    perl -e '
      my $secs = shift;
      my $pid = fork();
      if ($pid == 0) { exec @ARGV; exit 127; }
      local $SIG{ALRM} = sub { kill "TERM", $pid; sleep 2; kill "KILL", $pid; exit 124; };
      alarm $secs;
      waitpid($pid, 0);
      exit($? >> 8);
    ' "$MODEL_HARD_TIMEOUT" gemini -y -m "$model" -o json -p "$PROMPT" \
      </dev/null
  ) >"$out_file" 2>"$err_file"
  rc=$?

  # Output JSON parsing — extract the actual response text from --output-format json
  # Gemini JSON shape: {"response": "...text..."} or {"text": "..."} (varies by version)
  local body=""
  if [[ -s "$out_file" ]]; then
    body=$(jq -r '.response // .text // .output // empty' "$out_file" 2>/dev/null)
    if [[ -z "$body" ]]; then
      # Not JSON or unexpected shape — pass raw
      body=$(cat "$out_file")
    fi
  fi

  if [[ "$rc" -eq 0 && -n "$body" ]]; then
    echo "$body"
    rm -f "$out_file" "$err_file"
    return 0
  fi

  # Failure — emit combined stream to stderr for classifier upstream
  cat "$err_file" >&2
  [[ -s "$out_file" ]] && cat "$out_file" >&2
  rm -f "$out_file" "$err_file"
  return "$rc"
}

# ── Main loop ───────────────────────────────────────────────────────────

global_attempts=0
last_error_class="unknown"

for model in "${FALLBACK_CHAIN[@]}"; do
  if circuit_is_open "$model"; then
    stderr "skip $model (circuit OPEN)"
    log_event "$model" 0 "circuit_open" 0 "null"
    continue
  fi

  for ((attempt=1; attempt<=MODEL_ATTEMPT_CAP; attempt++)); do
    if (( global_attempts >= GLOBAL_ATTEMPT_BUDGET )); then
      stderr "global budget exhausted ($GLOBAL_ATTEMPT_BUDGET attempts)"
      break 2
    fi
    global_attempts=$((global_attempts + 1))

    stderr "trying $model (model attempt $attempt/$MODEL_ATTEMPT_CAP, global $global_attempts/$GLOBAL_ATTEMPT_BUDGET)"

    started=$(date +%s)
    if output=$(try_model "$model" 2> /tmp/gemini-supervisor-err.$$); then
      ended=$(date +%s)
      latency=$(( (ended - started) * 1000 ))
      record_success "$model"
      log_event "$model" "$attempt" "success" "$latency" "null"
      stderr "success on $model in ${latency}ms"
      printf '%s\n' "$output"
      rm -f /tmp/gemini-supervisor-err.$$
      exit 0
    fi

    ended=$(date +%s)
    latency=$(( (ended - started) * 1000 ))
    err_combined=$(cat /tmp/gemini-supervisor-err.$$ 2>/dev/null || true)
    rm -f /tmp/gemini-supervisor-err.$$

    error_class=$(classify_error "$err_combined")
    last_error_class="$error_class"
    log_event "$model" "$attempt" "$error_class" "$latency" "null"
    stderr "$model attempt $attempt failed: $error_class"

    case "$error_class" in
      quota_exhausted|auth_error)
        # Don't retry same model — fall through to next
        record_failure "$model"
        break
        ;;
      short_burst|model_capacity)
        record_failure "$model"
        if (( attempt < MODEL_ATTEMPT_CAP )); then
          delay=$(backoff_secs "$attempt")
          stderr "backoff ${delay}s before retry"
          sleep "$delay"
        fi
        ;;
      other)
        # Unknown error — log full stderr once and fall through
        stderr "uncategorized error, full stderr:"
        echo "$err_combined" | head -10 >&2
        record_failure "$model"
        break
        ;;
    esac
  done
done

stderr "all fallback models exhausted (last error: $last_error_class)"
exit 1
