#!/usr/bin/env bash
# kimi-dispatch.sh — Robust Kimi wrapper for the dispatch skill
# Handles: endpoint routing (Moonshot vs coding), CLI flags, empty output detection, API fallback, JSON parsing
#
# Endpoint routing:
#   Default        → Moonshot 通用 (api.moonshot.cn/v1, model=kimi-k2.6)
#                    特点: reasoning 可见，保留追问倾向；适合通用分析 / 综合问答
#   KIMI_FOR_CODING=1 → kimi-for-coding (kimi CLI + api.kimi.com/coding/v1)
#                    特点: 输出体量更大，自带 agent harness，reasoning 不可见
#                    适合: 长篇报告 / agent 自主写文件 / 多步骤代码任务
#
# Usage:
#   kimi-dispatch.sh "your prompt here"                   # 默认走 Moonshot
#   KIMI_FOR_CODING=1 kimi-dispatch.sh "prompt"           # 显式走 coding
#   kimi-dispatch.sh --stdin < prompt.txt                 # stdin 输入
# Exit:  0 = success (output on stdout), 1 = all methods failed (error on stderr)

set -euo pipefail

# Accept prompt via $1 OR --stdin (read from stdin)
if [[ "${1:-}" == "--stdin" ]]; then
  PROMPT=$(cat)
  if [[ -z "$PROMPT" ]]; then
    echo "[kimi-dispatch] --stdin specified but stdin was empty" >&2
    exit 1
  fi
else
  PROMPT="${1:?Usage: kimi-dispatch.sh \"prompt\"  |  kimi-dispatch.sh --stdin < prompt.txt}"
fi
TIMEOUT="${KIMI_TIMEOUT:-300}"  # kimi-k2.6 是 thinking 模型，长 prompt reasoning 阶段较慢，默认 timeout 设得较长
CLI_TIMEOUT="${KIMI_CLI_TIMEOUT:-60}"  # CLI hard timeout; on expiry, fall back to API

# Endpoint routing
USE_CODING="${KIMI_FOR_CODING:-0}"

# --- Logging (JSONL) — same format as gemini-supervisor.sh ---
LOG_DIR="$HOME/.cache/dispatch"
LOG_FILE="$LOG_DIR/kimi.log"
mkdir -p "$LOG_DIR"

log_event() {
  local model="$1" attempt="$2" status="$3" latency_ms="$4" extra="$5"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{"ts":"%s","model":"%s","attempt":%d,"status":"%s","latency_ms":%d,"extra":%s}\n' \
    "$ts" "$model" "$attempt" "$status" "$latency_ms" "${extra:-null}" \
    >> "$LOG_FILE"
}

# ============================================================
# Path A: coding endpoint (KIMI_FOR_CODING=1)
# ============================================================
if [[ "$USE_CODING" == "1" ]]; then
  # --- Method 1: kimi CLI (kimi-for-coding 后端) ---
  if command -v kimi &>/dev/null; then
    started=$(date +%s)
    rc=0
    OUTPUT=$(perl -e 'alarm shift; exec @ARGV' "$CLI_TIMEOUT" \
      kimi -p "$PROMPT" --quiet </dev/null 2>/dev/null) || rc=$?
    ended=$(date +%s)
    latency=$(( (ended - started) * 1000 ))

    CLEAN=$(
      printf '%s' "$OUTPUT" |
      perl -pe 's/\e\[[0-9;]*[a-zA-Z]//g' |
      sed -E '/^To resume this session:/d' |
      tr -d '[:space:]•·'
    )
    if [[ -n "$CLEAN" ]]; then
      log_event "kimi-cli-coding" 1 "success" "$latency" "null"
      printf '%s\n' "$OUTPUT"
      exit 0
    fi

    if [[ $latency -ge $((CLI_TIMEOUT * 1000)) ]] || [[ $rc -eq 142 ]]; then
      log_event "kimi-cli-coding" 1 "cli_timeout" "$latency" "{\"cli_timeout_sec\":$CLI_TIMEOUT}"
      echo "[kimi-dispatch] CLI exceeded ${CLI_TIMEOUT}s, falling back to coding API" >&2
    else
      log_event "kimi-cli-coding" 1 "cli_empty" "$latency" "null"
      echo "[kimi-dispatch] CLI returned empty output, falling back to coding API" >&2
    fi
  fi

  # --- Method 2: coding REST API fallback ---
  KIMI_ENV="$HOME/.config/ai-keys/kimi.env"
  if [[ -f "$KIMI_ENV" ]]; then
    # shellcheck source=/dev/null
    source "$KIMI_ENV"
  fi

  if [[ -z "${KIMI_API_KEY:-}" ]]; then
    log_event "kimi-api-coding" 2 "no_api_key" 0 "null"
    echo "[kimi-dispatch] No KIMI_API_KEY found in ~/.config/ai-keys/kimi.env" >&2
    exit 1
  fi

  JSON_PROMPT=$(printf '%s' "$PROMPT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || true)
  if [[ -z "$JSON_PROMPT" ]]; then
    log_event "kimi-api-coding" 2 "json_encode_fail" 0 "null"
    echo "[kimi-dispatch] Failed to JSON-encode prompt (python3 unavailable?)" >&2
    exit 1
  fi

  api_started=$(date +%s)
  API_RESPONSE=$(curl -s --max-time "$TIMEOUT" \
    https://api.kimi.com/coding/v1/messages \
    -H "Content-Type: application/json" \
    -H "x-api-key: $KIMI_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "{\"model\":\"kimi-for-coding\",\"max_tokens\":4096,\"messages\":[{\"role\":\"user\",\"content\":${JSON_PROMPT}}]}" \
    2>/dev/null || true)
  api_ended=$(date +%s)
  api_latency=$(( (api_ended - api_started) * 1000 ))

  if [[ -z "$API_RESPONSE" ]]; then
    log_event "kimi-api-coding" 2 "api_empty" "$api_latency" "null"
    echo "[kimi-dispatch] Coding API returned empty response" >&2
    exit 1
  fi

  if command -v jq &>/dev/null; then
    CONTENT=$(echo "$API_RESPONSE" | jq -r '.content[]? | select(.type=="text") | .text // empty' 2>/dev/null || true)
    if [[ -z "$CONTENT" ]]; then
      CONTENT=$(echo "$API_RESPONSE" | jq -r '.choices[0]?.message?.content // empty' 2>/dev/null || true)
    fi
  else
    CONTENT=$(echo "$API_RESPONSE" | python3 -c '
import sys, json
try:
    r = json.load(sys.stdin)
    if "content" in r:
        print("\n".join(b["text"] for b in r["content"] if b.get("type")=="text"))
    elif "choices" in r:
        print(r["choices"][0]["message"]["content"])
except: pass
' 2>/dev/null || true)
  fi

  if [[ -n "$CONTENT" ]]; then
    log_event "kimi-api-coding" 2 "success" "$api_latency" "null"
    printf '%s\n' "$CONTENT"
    exit 0
  fi

  log_event "kimi-api-coding" 2 "parse_fail" "$api_latency" "null"
  echo "[kimi-dispatch] Could not parse coding API response. Raw:" >&2
  echo "$API_RESPONSE" >&2
  exit 1
fi

# ============================================================
# Path B: Moonshot 通用 endpoint（默认）
# ============================================================
MOONSHOT_ENV="$HOME/.config/ai-keys/kimi-moonshot.env"
if [[ -f "$MOONSHOT_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$MOONSHOT_ENV"
fi

if [[ -z "${MOONSHOT_API_KEY:-}" ]]; then
  log_event "kimi-moonshot" 1 "no_api_key" 0 "null"
  echo "[kimi-dispatch] No MOONSHOT_API_KEY found in ~/.config/ai-keys/kimi-moonshot.env" >&2
  echo "[kimi-dispatch] Hint: 设置 KIMI_FOR_CODING=1 fallback to coding endpoint" >&2
  exit 1
fi

# Moonshot 通用 K2.6 走 OpenAI 兼容格式 chat/completions（默认 streaming + 可禁 thinking）
# 设计：thinking 模型完成时间长尾不可预测 → 必须用 SSE streaming + idle guard，避免单 timeout 黑盒等待
# ENV:
#   KIMI_NO_THINK=1      → 注入 {"thinking":{"type":"disabled"}} 走快档（4s 级）
#   KIMI_TIMEOUT=900     → 总 timeout hard cap（默认 900s）
#   KIMI_IDLE_TIMEOUT=120 → idle guard，无 byte 流入 120s 才断（区分"模型还活着"vs"连接死了"）
#   KIMI_MAX_TOKENS=16384
#   MOONSHOT_MODEL=kimi-k2.6

MOONSHOT_MODEL="${MOONSHOT_MODEL:-kimi-k2.6}"
MAX_TOKENS="${KIMI_MAX_TOKENS:-16384}"
STREAM_TIMEOUT="${KIMI_TIMEOUT:-900}"    # 在 streaming 模式下，覆盖前面 line 34 的 300 默认值
IDLE_TIMEOUT="${KIMI_IDLE_TIMEOUT:-120}"

# 用 python3 安全构造 payload（避免 bash JSON 拼接坑）
PAYLOAD=$(python3 - "$MOONSHOT_MODEL" "$MAX_TOKENS" "$PROMPT" <<'PY'
import json, os, sys
model = sys.argv[1]
max_tokens = int(sys.argv[2])
prompt = sys.argv[3]
body = {
    "model": model,
    "max_tokens": max_tokens,
    "stream": True,
    "messages": [{"role": "user", "content": prompt}],
}
if os.getenv("KIMI_NO_THINK") == "1":
    body["thinking"] = {"type": "disabled"}
print(json.dumps(body, ensure_ascii=False))
PY
)

if [[ -z "$PAYLOAD" ]]; then
  log_event "kimi-moonshot" 1 "payload_build_fail" 0 "null"
  echo "[kimi-dispatch] Failed to build payload (python3 unavailable?)" >&2
  exit 1
fi

# 把 SSE 解析脚本落地成临时文件，避免 `python3 - <<HEREDOC` 模式吃掉 stdin pipe 的坑
# （已知 bug：`python3 - <<'PY' ... PY` 中 `-` + heredoc 同时占用 stdin，curl 流无法流入 python）
SSE_PARSER=$(mktemp -t kimi-sse-parser.XXXXXX.py)
trap 'rm -f "$SSE_PARSER" /tmp/kimi-curl-err.$$' EXIT
cat > "$SSE_PARSER" <<'PY'
import json, sys
content_parts = []
reasoning_chars = 0
for raw in sys.stdin:
    line = raw.strip()
    if not line or not line.startswith("data:"):
        continue
    data = line[len("data:"):].strip()
    if data == "[DONE]":
        break
    try:
        obj = json.loads(data)
    except json.JSONDecodeError:
        continue
    choices = obj.get("choices") or []
    if not choices:
        continue
    delta = choices[0].get("delta") or {}
    reasoning = delta.get("reasoning_content")
    if reasoning:
        reasoning_chars += len(reasoning)
        if sys.stderr.isatty():
            print(reasoning, end="", file=sys.stderr, flush=True)
    text = delta.get("content")
    if text:
        content_parts.append(text)
full = "".join(content_parts)
print(full)
print(f"[kimi-stream] reasoning_chars={reasoning_chars} content_chars={len(full)}", file=sys.stderr)
PY

api_started=$(date +%s)
# SSE streaming + idle guard：
#   --no-buffer：禁 curl 输出缓冲（必须，否则 streaming 失效）
#   --speed-limit 1 --speed-time N：N 秒无 byte 流入即断（idle guard）
#   --max-time：总时长 hard cap
STREAM_OUTPUT=$(curl -sS --no-buffer \
  --connect-timeout 30 \
  --speed-limit 1 \
  --speed-time "$IDLE_TIMEOUT" \
  --max-time "$STREAM_TIMEOUT" \
  https://api.moonshot.cn/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MOONSHOT_API_KEY" \
  -d "$PAYLOAD" 2>/tmp/kimi-curl-err.$$ |
python3 "$SSE_PARSER") || rc=$?

api_ended=$(date +%s)
api_latency=$(( (api_ended - api_started) * 1000 ))
curl_err=$(cat /tmp/kimi-curl-err.$$ 2>/dev/null || true)
rm -f /tmp/kimi-curl-err.$$

# STREAM_OUTPUT 末尾的 print 会带换行；判 content 是否非空（剥掉末尾换行）
CONTENT=$(printf '%s' "$STREAM_OUTPUT")

if [[ -n "$CONTENT" ]]; then
  log_event "kimi-moonshot" 1 "success" "$api_latency" "{\"model\":\"$MOONSHOT_MODEL\",\"mode\":\"streaming\"}"
  printf '%s\n' "$CONTENT"
  exit 0
fi

# 失败诊断：分别报告 curl 错误和 latency
if [[ $api_latency -ge $((STREAM_TIMEOUT * 1000)) ]]; then
  log_event "kimi-moonshot" 1 "max_time_hit" "$api_latency" "{\"timeout\":$STREAM_TIMEOUT}"
  echo "[kimi-dispatch] Hit --max-time ${STREAM_TIMEOUT}s ceiling. Try KIMI_NO_THINK=1 for fast path or raise KIMI_TIMEOUT." >&2
elif [[ -n "$curl_err" ]]; then
  log_event "kimi-moonshot" 1 "curl_error" "$api_latency" "null"
  echo "[kimi-dispatch] curl error: $curl_err" >&2
else
  log_event "kimi-moonshot" 1 "empty_content" "$api_latency" "null"
  echo "[kimi-dispatch] Streaming completed but content was empty (model returned only reasoning?)" >&2
  echo "[kimi-dispatch] Hint: try KIMI_NO_THINK=1 to force content output without reasoning consuming tokens" >&2
fi
exit 1
