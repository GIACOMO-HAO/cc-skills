---
name: giasip-dispatch
version: 1.2.0
description: “Multi-model dispatcher -- sends a task or prompt to other AI models (Codex / Gemini / Kimi / DeepSeek / Doubao / Qwen / GLM / MiniMax) and retrieves results. Triggers when you want to run a task on a specific model, need multi-model cross-validation, or want to use a cheaper model.”
author: GiaSip <https://github.com/GiaSip>
license: MIT
compatibility: claude-code, codex
---

> ✦ A **GiaSip** skill · part of the `giasip` toolkit · github.com/GiaSip

# /dispatch — Multi-Model Dispatcher

Sends a task or prompt to another AI model for execution and retrieves the result. This skill **only provides the dispatch capability** — which model to pick, whether to fan out to multiple models, is decided by you (or the current Claude) based on the task at hand. No built-in model preference.

## Two Dispatch Channels

| Channel | Models | Prerequisite |
|---------|--------|-------------|
| **API direct call** (curl, fastest) | DeepSeek / Qwen / GLM / Doubao / MiniMax | Just place the corresponding `.env` in `~/.config/ai-keys/` (with API key) |
| **CLI invocation** | Codex / Gemini / Kimi | Requires local install + login for each CLI |
| **Internal SubAgent** | Claude Haiku / Sonnet | Built into Claude Code, no external dependency |

> For pure thinking/analysis tasks (no file I/O, no command execution, no code changes), prefer **API direct call** — roughly 10x faster than CLI. Use CLI only when the task needs agent capabilities (file system access, command execution, code changes).

---

## General Discipline (must-read for all CLI calls)

1. **Use heredoc for prompts** — avoids quoting / special character issues.
2. **Append `</dev/null` to all CLI calls** — Claude Code's Bash environment has a never-closing stdin pipe; without this, CLIs hang waiting for input.
3. **When constructing prompts**: keep them concise and clear; don't inject Claude Code-specific concepts (skills / hooks / SubAgent); use Chinese prompts for Chinese tasks, English for English; include necessary project context when relevant.

---

## Complexity Routing

Automatically select the dispatch strategy based on task nature:

```
Visual task? (PDF catalog / scanned doc / screenshot / image parsing)
├── Yes → [Gemini CLI] — native PDF + image visual analysis
│   Trigger: user provides image/PDF path + task involves "reading" content;
│   or markitdown output is empty/abnormally small
│   → Do NOT try markitdown first — route directly to Gemini
│
├── Pure thinking/analysis (business analysis, strategy, text understanding, translation)
│   → [API direct call] — no agent capability needed, curl the API directly
│   10x faster; supports models without CLI (DeepSeek/Qwen/GLM etc.)
│
├── Simple + reversible (install packages, format, search, generate templates)
│   → [Single dispatch] — prefer Claude SubAgent (Haiku) for speed
│   Use external CLI only when the task needs Chinese-native or specific AI capabilities
│
├── Code execution (bug fix, write tests, small refactor, generate code files)
│   → [Codex write mode] — sandbox=full, Codex modifies code directly
│   Condition: clear task, in a git-managed project, controllable blast radius
│   Always remind user to `git diff` afterward
│
├── Medium complexity (feature dev, document analysis, code analysis)
│   → [Single dispatch] — send to the best-fit AI
│
├── Complex + irreversible (architecture design, tech selection, major refactor)
│   → [Multi-dispatch] — auto-escalate, send to 2-3 AIs, compare outputs
│
└── User specifies AI ("run this with Kimi")
    → [Direct assignment] — send to specified AI, skip matching
```

**Multi-dispatch triggers** (any one auto-escalates):
- User says "important", "critical decision", "can't be wrong"
- Task involves irreversible operations (database migration, production deployment)
- Task is tech selection or architecture design
- Estimated blast radius > 10 files or 3 modules
- Chinese business/strategic analysis tasks (default: three-way parallel)

→ See `references/model-roster.md` for multi-dispatch lineup recommendations by task type.

---

## Dispatch Methods

### API Direct Call (DeepSeek / Qwen / GLM / Doubao / MiniMax)

For pure analysis tasks that don't need agent capabilities, call the API directly:

```bash
${CLAUDE_SKILL_DIR}/scripts/api-dispatch.sh --model <model> "$(cat <<'EOF'
prompt content
EOF
)"
```

Long text via stdin:

```bash
echo "long text content" | ${CLAUDE_SKILL_DIR}/scripts/api-dispatch.sh --model <model> --stdin
```

Supported models — see `references/model-roster.md` for the full roster with per-model strengths and multi-dispatch lineup recommendations.

| Parameter | Model | Key File | Context |
|-----------|-------|----------|---------|
| `deepseek` | DeepSeek V4-Pro (thinking mode on) | `deepseek.env` | 1M |
| `qwen` | Qwen3.6 Plus (Tongyi) | `dashscope.env` | 1M |
| `glm` | GLM-5.1 (Zhipu flagship) | `zai.env` | 200K |
| `doubao` | Doubao Seed-2.0 Pro (ByteDance) | `volcengine.env` | 256K |
| `minimax` | MiniMax M2.7 | `minimax.env` | — |

> Model names evolve with vendor updates — check vendor docs before calling.

### Codex CLI (OpenAI) — App Server protocol, no cold start

Read-only mode (analysis / review / research):

```bash
node ${CLAUDE_SKILL_DIR}/scripts/codex-appserver.mjs --effort xhigh "$(cat <<'EOF'
prompt content
EOF
)" </dev/null
```

Write mode (code changes / bug fixes / test generation / file creation):

```bash
node ${CLAUDE_SKILL_DIR}/scripts/codex-appserver.mjs --effort xhigh --sandbox full "$(cat <<'EOF'
prompt content
EOF
)" </dev/null
```

**Write mode safety rules:**
- Only use in git-managed project directories (`--cwd /path/to/project`)
- After execution, always remind the user to `git diff` to review changes; `git checkout .` to revert if unsatisfied
- For production code / databases / deployment scripts, downgrade to read-only mode + output recommendations instead

**Notes:**
- `--sandbox` defaults to `read-only`; write mode uses `full` (the script also supports `workspace-write` / `danger-full-access` for advanced use)
- The script has built-in non-ASCII path auto-symlink workaround (`--cwd` with CJK characters auto-creates a temp symlink in `/tmp`, cleaned up on exit)
- Do not add `2>/dev/null` — the script outputs structured progress and error info on stderr
- Long text can use stdin: `echo "long text" | node ${CLAUDE_SKILL_DIR}/scripts/codex-appserver.mjs --stdin --effort xhigh`

### Gemini CLI (Google) — supervisor script recommended

The supervisor has built-in smart retry / fallback chain / circuit breaker / timeout / logging:

```bash
${CLAUDE_SKILL_DIR}/scripts/gemini-supervisor.sh --cwd "/path/to/work/dir" "$(cat <<'PROMPT_END'
prompt content
PROMPT_END
)"
```

**Supervisor default behavior:**
- Fallback chain: flagship model → GA stable → flash (auto-skips if unavailable)
- Error classification: 429 short-term congestion → backoff + jitter retry; daily quota exhaustion → skip to next model; 503 → same backoff path
- Global attempt budget: 6; per-model hard timeout: 600s (configurable via `GEMINI_MODEL_TIMEOUT`)
- Circuit breaker: 3 consecutive failures per model → 30-minute cool-down
- Logs: `~/.cache/dispatch/gemini.log` (JSONL) + state: `~/.cache/dispatch/gemini-state.json`

**Specify a single model (skip fallback):** `${CLAUDE_SKILL_DIR}/scripts/gemini-supervisor.sh --model <model-id> "prompt"`
**stdin mode (recommended for long prompts):** `cat prompt.txt | ${CLAUDE_SKILL_DIR}/scripts/gemini-supervisor.sh --stdin --cwd "/work/dir"`

**Gemini vision / PDF parsing** (Gemini natively supports PDF + image visual analysis — the standard path for scanned PDFs / screenshots):

```bash
${CLAUDE_SKILL_DIR}/scripts/gemini-supervisor.sh \
  --cwd "/path/to/files/dir" \
  "$(cat <<'PROMPT_END'
Please fully parse all pages of xxx.pdf and output in markdown format:
- Preserve all data tables (use markdown table syntax)
- Preserve all specs, technical parameters, model numbers
- Annotate page numbers (## Page 1 / ## Page 2 ...)
- Do not omit any technical details
PROMPT_END
)" > output.md
```

Use cases: PDF catalogs (no text layer), scans, product datasheets, screenshot analysis, image OCR, chart data extraction. Pipe to file (`... > output.md`) for large outputs to avoid stdout truncation.

### Kimi CLI (Moonshot) — wrapper script recommended, auto endpoint routing

> **Thinking model discipline**: Kimi K2.6 is a thinking model — reasoning can take minutes for complex prompts. **Bash timeout must be ≥600000** (10 min) for complex tasks. The script has built-in SSE streaming + idle guard (120s no-byte threshold) + 900s hard cap. Do NOT kill mid-run or substitute with hand-written curl. For fast mode: prefix `KIMI_NO_THINK=1` (injects `{"thinking":{"type":"disabled"}}`, ~4s response, but quality drops — only for non-reasoning tasks).

```bash
# Default: Moonshot general endpoint (api.moonshot.cn/v1, MOONSHOT_API_KEY)
${CLAUDE_SKILL_DIR}/scripts/kimi-dispatch.sh "$(cat <<'EOF'
prompt content
EOF
)"

# Opt-in coding endpoint (Kimi CLI + api.kimi.com/coding/v1, KIMI_API_KEY)
KIMI_FOR_CODING=1 ${CLAUDE_SKILL_DIR}/scripts/kimi-dispatch.sh "prompt"

# Fast mode (disable thinking, ~4s response)
KIMI_NO_THINK=1 ${CLAUDE_SKILL_DIR}/scripts/kimi-dispatch.sh "simple task"
```

| Endpoint | Characteristics | Best for |
|----------|----------------|----------|
| **Default Moonshot general** | Reasoning visible, retains follow-up tendency | General analysis, Q&A |
| `KIMI_FOR_CODING=1` | Larger output volume, built-in agent harness, reasoning hidden | Long reports, agent-driven file writing, multi-step code |

### Claude Code Internal SubAgent (no external CLI)

For simple tasks use Haiku, for standard tasks use Sonnet — spawn a SubAgent via the Agent tool (specify `model: haiku` or `model: sonnet`). Faster and cheaper than headless CLI, with no external dependencies.

---

## Environment Check

Quick availability check before dispatching:

```bash
# CLI tools
command -v codex; command -v gemini; command -v kimi

# API keys (for API direct calls)
ls ~/.config/ai-keys/*.env 2>/dev/null
```

Only dispatch to available models. If a CLI is unavailable, fall back to API direct call or switch models; an existing API key file means that model is callable.

---

## Multi-Model Parallel (cross-validation / multi-perspective)

When you need multiple models to give independent perspectives on the same question, **fire multiple Bash calls in parallel** and have Claude synthesize the results. Typical scenarios: important decisions, tech selection, pre-flight check before irreversible actions, low confidence in a single model's output.

```bash
# Three-way parallel example (same prompt to three models)
${CLAUDE_SKILL_DIR}/scripts/kimi-dispatch.sh "analysis task" &
${CLAUDE_SKILL_DIR}/scripts/api-dispatch.sh --model deepseek "analysis task" &
${CLAUDE_SKILL_DIR}/scripts/api-dispatch.sh --model doubao "analysis task" &
wait
```

Selection principle: cognitive diversity > quantity — pick models with different training data / architecture to get genuinely different perspectives; always use each model's highest tier; control cost by controlling frequency, not by downgrading per-call quality.

---

## Execution Parameters

- **Bash timeout:**
  - Codex deep reasoning (xhigh): `600000` (10 minutes, Bash tool ceiling, aligned with script default 600s)
  - Gemini single dispatch: `240000` (4 minutes); multi-dispatch per route `300000` (5 minutes)
  - **Kimi (thinking model)**: single/multi-dispatch always `≥600000` (reasoning tail is long and unpredictable); only `KIMI_NO_THINK=1` fast mode can use `240000`
- Single dispatch = one Bash call; multi-dispatch = multiple Bash calls fired in parallel
- Codex uses App Server protocol with no cold start; xhigh deep reasoning typically takes 3-8 minutes
- Gemini / Kimi use CLI headless mode; keep `2>/dev/null`

## Fallback Chain

```
Primary channel fails (timeout / error)
→ Try alternative model (similar capability)
→ Alternative also fails
→ Downgrade to "recommendation only" mode: output suggested approach but don't execute, hand back to user
```

---

## Output Format

**Single dispatch:**

```markdown
## Task Result
**Executor:** [model name]  **Task:** [one-line recap]

### Result
[model output]

### Execution Info
- Duration: [X seconds]  Status: [success / partial / failed]
```

**Multi-dispatch:**

```markdown
## Task Result (Multi-Dispatch)
**Task:** [one-line recap]

### [Model 1]'s Take
[3-5 key points]

### [Model 2]'s Take
[3-5 key points]

### Synthesis
- **Consensus:** [what all parties agree on]
- **Divergence:** [differences, with each party's position noted]
- **My judgment:** [Claude's independent assessment as the orchestrator]
```

---

## Response Logging

Use `dispatch-persist.mjs` to persist **complete first-hand responses** to `~/.cache/dispatch/responses/YYYY/MM/DD/<response_id>.md` (YAML frontmatter + prompt + response) and append to `~/.cache/dispatch/index.jsonl` (consumption entry point). Pipe dispatch output to this script, or hook it into your dispatch scripts to avoid losing responses to volatile /tmp or session logs.

For multi-dispatch runs, set `DISPATCH_BATCH_ID` to group responses from the same batch:

```bash
batch_id="$(uuidgen)"
DISPATCH_BATCH_ID="$batch_id" ${CLAUDE_SKILL_DIR}/scripts/kimi-dispatch.sh "task" &
DISPATCH_BATCH_ID="$batch_id" ${CLAUDE_SKILL_DIR}/scripts/api-dispatch.sh --model deepseek "task" &
wait
```

Implementation: see `${CLAUDE_SKILL_DIR}/scripts/dispatch-persist.mjs`.

---

## Script Inventory

| Script | Purpose |
|--------|---------|
| `api-dispatch.sh` | API direct call (DeepSeek / Qwen / GLM / Doubao / MiniMax) |
| `codex-appserver.mjs` | Codex App Server protocol (read-only / write mode) |
| `gemini-supervisor.sh` | Gemini CLI + retry / fallback / circuit breaker |
| `kimi-dispatch.sh` | Kimi dispatch + endpoint routing + thinking mode control |
| `dispatch-persist.mjs` | Response logging — auto-persists dispatch results to disk |
| `stop-review-gate.mjs` | Codex stop hook — gates on code review before stopping |

> For installation, dependencies, and API key setup, see README.md.
