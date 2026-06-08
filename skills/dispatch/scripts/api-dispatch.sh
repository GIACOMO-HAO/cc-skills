#!/usr/bin/env bash
# api-dispatch.sh — API 直调派遣脚本（DeepSeek/Qwen/GLM/豆包/MiniMax）
# 用于无 CLI Agent 的模型，通过 OpenAI 兼容 API 直接调用完成纯分析任务
# 比 CLI Agent 快 10 倍——无启动开销，直接发请求收回答
#
# Usage:
#   api-dispatch.sh --model <qwen|deepseek|glm|doubao|minimax> "prompt"
#   echo "长文本" | api-dispatch.sh --model <model> --stdin
#
# Exit: 0 = success (output on stdout), 1 = failed (error on stderr)

set -euo pipefail

MODEL=""
PROMPT=""
USE_STDIN=false
TIMEOUT_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model|-m) MODEL="$2"; shift 2 ;;
    --timeout|-t) TIMEOUT_OVERRIDE="$2"; shift 2 ;;
    --stdin) USE_STDIN=true; shift ;;
    --help|-h)
      echo "Usage: api-dispatch.sh --model <qwen|deepseek|glm|doubao|minimax> \"prompt\""
      echo "       echo \"prompt\" | api-dispatch.sh --model <model> --stdin"
      echo ""
      echo "Models:"
      echo "  qwen      Qwen3.6 Plus (阿里通义) — 信息整合/长文档/图表"
      echo "  deepseek  DeepSeek V4-Pro 思考模式 — 拆逻辑/假设验证（1M ctx）"
      echo "  glm       GLM-5.1 (智谱旗舰)    — 事实核查/低幻觉"
      echo "  doubao    豆包 Seed-2.0 Pro      — 中文表达/写作润色"
      echo "  minimax   MiniMax M2.7           — 编程/Office文档"
      exit 0
      ;;
    *) PROMPT="$1"; shift ;;
  esac
done

# Read from stdin if --stdin flag is set
if $USE_STDIN; then
  PROMPT=$(cat)
fi

if [[ -z "$MODEL" || -z "$PROMPT" ]]; then
  echo "Usage: api-dispatch.sh --model <qwen|deepseek|glm|doubao|minimax> \"prompt\"" >&2
  exit 1
fi

TIMEOUT="${TIMEOUT_OVERRIDE:-${API_TIMEOUT:-180}}"
AI_KEYS_DIR="$HOME/.config/ai-keys"

# --- Model configurations ---
case "$MODEL" in
  qwen|qwen-max|qwen-plus|qwen3.5|qwen3.6)
    KEY_FILE="$AI_KEYS_DIR/dashscope.env"
    API_URL="https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    MODEL_ID="qwen3.6-plus"
    DISPLAY_NAME="Qwen3.6 Plus (通义千问)"
    ;;
  deepseek|deepseek-r1|deepseek-reasoner|deepseek-v4)
    KEY_FILE="$AI_KEYS_DIR/deepseek.env"
    API_URL="https://api.deepseek.com/chat/completions"
    MODEL_ID="deepseek-v4-pro"
    DISPLAY_NAME="DeepSeek V4-Pro"
    ;;
  glm|glm-4|glm-4-plus|glm-5|glm-5.1)
    KEY_FILE="$AI_KEYS_DIR/zai.env"
    API_URL="https://open.bigmodel.cn/api/paas/v4/chat/completions"
    MODEL_ID="glm-5.1"
    DISPLAY_NAME="GLM-5.1 (智谱)"
    ;;
  doubao|doubao-pro|seed|volcengine)
    KEY_FILE="$AI_KEYS_DIR/volcengine.env"
    API_URL="https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    MODEL_ID="doubao-seed-2-0-pro-260215"
    DISPLAY_NAME="豆包 Seed-2.0 Pro (字节)"
    ;;
  minimax|minimax-m2.7|m2.7)
    KEY_FILE="$AI_KEYS_DIR/minimax.env"
    API_URL="https://api.minimax.io/v1/chat/completions"
    MODEL_ID="MiniMax-M2.7"
    DISPLAY_NAME="MiniMax M2.7"
    ;;
  *)
    echo "[api-dispatch] 不支持的模型: $MODEL" >&2
    echo "[api-dispatch] 支持: qwen, deepseek, glm, doubao, minimax" >&2
    exit 1
    ;;
esac

# --- Load API key ---
if [[ ! -f "$KEY_FILE" ]]; then
  echo "[api-dispatch] Key 文件不存在: $KEY_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$KEY_FILE"

# Try common API key variable names (covers different naming conventions)
API_KEY=""
for var in DASHSCOPE_API_KEY DEEPSEEK_API_KEY ZAI_API_KEY ZHIPUAI_API_KEY BIGMODEL_API_KEY VOLCENGINE_API_KEY VOLC_API_KEY ARK_API_KEY MINIMAX_API_KEY API_KEY; do
  if [[ -n "${!var:-}" ]]; then
    API_KEY="${!var}"
    break
  fi
done

if [[ -z "$API_KEY" ]]; then
  echo "[api-dispatch] 在 $KEY_FILE 中未找到 API key" >&2
  echo "[api-dispatch] 请确保 .env 定义了对应 API key（DEEPSEEK_API_KEY / DASHSCOPE_API_KEY / ZAI_API_KEY / ARK_API_KEY / MINIMAX_API_KEY 之一）" >&2
  exit 1
fi

# --- JSON-encode prompt ---
JSON_PROMPT=$(printf '%s' "$PROMPT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || true)
if [[ -z "$JSON_PROMPT" ]]; then
  echo "[api-dispatch] JSON 编码失败（需要 python3）" >&2
  exit 1
fi

echo "[api-dispatch] 正在调用 $DISPLAY_NAME..." >&2

# --- Call API (OpenAI-compatible format) ---
API_RESPONSE=$(curl -s --max-time "$TIMEOUT" \
  "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{\"model\":\"$MODEL_ID\",\"max_tokens\":8192,\"messages\":[{\"role\":\"user\",\"content\":${JSON_PROMPT}}]}" \
  2>/dev/null || true)

if [[ -z "$API_RESPONSE" ]]; then
  echo "[api-dispatch] $DISPLAY_NAME 返回空响应（可能超时或网络错误）" >&2
  exit 1
fi

# --- Check for API error ---
ERROR_MSG=""
if command -v jq &>/dev/null; then
  ERROR_MSG=$(echo "$API_RESPONSE" | jq -r '.error?.message // empty' 2>/dev/null || true)
else
  ERROR_MSG=$(echo "$API_RESPONSE" | python3 -c '
import sys, json
try:
    r = json.load(sys.stdin)
    e = r.get("error", {})
    if e: print(e.get("message", "未知错误"))
except: pass
' 2>/dev/null || true)
fi

if [[ -n "$ERROR_MSG" ]]; then
  echo "[api-dispatch] $DISPLAY_NAME API 错误: $ERROR_MSG" >&2
  exit 1
fi

# --- Parse response ---
CONTENT=""
REASONING=""

if command -v jq &>/dev/null; then
  CONTENT=$(echo "$API_RESPONSE" | jq -r '.choices[0]?.message?.content // empty' 2>/dev/null || true)
  # DeepSeek R1 includes reasoning_content with full chain-of-thought
  REASONING=$(echo "$API_RESPONSE" | jq -r '.choices[0]?.message?.reasoning_content // empty' 2>/dev/null || true)
else
  CONTENT=$(echo "$API_RESPONSE" | python3 -c '
import sys, json
try:
    r = json.load(sys.stdin)
    c = r["choices"][0]["message"]
    print(c.get("content", ""))
except: pass
' 2>/dev/null || true)
fi

if [[ -n "$CONTENT" ]]; then
  # DeepSeek R1: prepend reasoning process if available
  if [[ -n "${REASONING:-}" && "$REASONING" != "null" && "$REASONING" != "" ]]; then
    echo "<details><summary>🧠 推理过程</summary>"
    echo ""
    printf '%s\n' "$REASONING"
    echo ""
    echo "</details>"
    echo ""
  fi
  printf '%s\n' "$CONTENT"
  exit 0
fi

# Last resort: dump raw response for debugging
echo "[api-dispatch] 无法解析 $DISPLAY_NAME 响应:" >&2
echo "$API_RESPONSE" | head -c 500 >&2
exit 1
