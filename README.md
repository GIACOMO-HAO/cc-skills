# giasip — research & dispatch skills

> ✦ A **GiaSip** skill toolkit for [Claude Code](https://claude.com/claude-code) · github.com/GiaSip

两个 Claude Code 自定义 skill，打包为 plugin `giasip`：

- **`research`** — 研究调度：先用 SubAgent 快速侦察（Quick Recon）摸清方向和知识缺口，再决定是否升级到外部 Deep Research 平台。内置两轮 Recon、Claim Ledger 质控、独立 fact-check 协议，让外部平台只处理真正需要深挖的盲点。
- **`dispatch`** — 多模型调用器：把任务或 prompt 一键派发给其他 AI 模型（Codex / Gemini / Kimi / DeepSeek / 豆包 / Qwen / GLM / MiniMax）执行并取回结果。

> `dispatch` 是**纯调用器**形态——只提供调用能力，不内置选型偏好（选哪个模型、单派还是多派，交给你自己的 Claude 临场判断）。

## 安装

### 方式一：作为 plugin 安装（推荐）

```
/plugin marketplace add GiaSip/giasip-skills
/plugin install giasip@giasip
```

装好后用 `/giasip:research`、`/giasip:dispatch` 触发，或直接描述意图（如「帮我调研一下…」「用 Kimi 跑一下…」）自动触发。

### 方式二：手动安装单个 skill

```bash
git clone https://github.com/GiaSip/giasip-skills
cp -R giasip-skills/skills/research ~/.claude/skills/research
cp -R giasip-skills/skills/dispatch ~/.claude/skills/dispatch
```

新开一个 Claude Code 会话即被自动发现，用 `/research`、`/dispatch` 触发。

> 两种方式都有效——skill 内的脚本路径使用 `${CLAUDE_SKILL_DIR}` 自动定位，无论装在 plugin 缓存目录还是 `~/.claude/skills/` 下都能正确解析。

---

## research — 依赖

**基本零外部依赖，开箱即用**——主要用 Claude Code 自带的 WebSearch / WebFetch / SubAgent（WebFetch 遇 JS 渲染页面时可选用 Firecrawl 作 fallback，非必需）。

唯一需要配置的：`skills/research/platform-profiles.md` 里有一张「平台可用性」表，按你自己实际订阅的 Deep Research 平台（ChatGPT / Gemini / Perplexity / Kimi 等）填一下 ✅/❌ 即可，匹配逻辑会据此跳过未订阅的平台。

---

## dispatch — 依赖

dispatch 有两类调用通道，按需配置：

### 1. API 直调（只需 API key，最快）

支持 DeepSeek / Qwen / GLM / 豆包 / MiniMax。在 `~/.config/ai-keys/` 放对应 `.env` 文件：

| 模型 | 文件 | 文件内容（环境变量） |
|------|------|---------------------|
| DeepSeek | `~/.config/ai-keys/deepseek.env` | `export DEEPSEEK_API_KEY=...` |
| Qwen（通义） | `~/.config/ai-keys/dashscope.env` | `export DASHSCOPE_API_KEY=...` |
| GLM（智谱） | `~/.config/ai-keys/zai.env` | `export ZAI_API_KEY=...` |
| 豆包（火山引擎） | `~/.config/ai-keys/volcengine.env` | `export ARK_API_KEY=...` |
| MiniMax | `~/.config/ai-keys/minimax.env` | `export MINIMAX_API_KEY=...` |

测试：`${CLAUDE_SKILL_DIR}/scripts/api-dispatch.sh --model deepseek "你好"`

> 各模型的具体模型名（如 `deepseek-v4-pro`、`doubao-seed-2-0-pro-260215`）写在 `api-dispatch.sh` 的 `case` 分支里，会随厂商版本更新——跑不通时先去脚本里改 `MODEL_ID`。

### 2. CLI 调用（需本地安装并登录对应 CLI）

| 模型 | 安装 | 登录 |
|------|------|------|
| Codex | `npm i -g @openai/codex` | ChatGPT 账号 |
| Gemini | `npm i -g @google/gemini-cli` | Google 账号 |
| Kimi | `uv tool install kimi-cli`（或仅用 API key） | kimi.com / Moonshot key |

Kimi 也可纯 API 调用（不装 CLI）：在 `~/.config/ai-keys/kimi-moonshot.env` 放 `export MOONSHOT_API_KEY=...`（默认通用 endpoint），或 `kimi.env` 放 `export KIMI_API_KEY=...`（coding endpoint，需 `KIMI_FOR_CODING=1`）。

依赖检查：`command -v codex gemini kimi node curl python3 jq`

### 其他

- Gemini 调用走 `gemini-supervisor.sh`，内置 retry / fallback chain / circuit breaker，日志写在 `~/.cache/dispatch/`。
- 需要 `python3`（JSON 编码）和 `jq`：`gemini-supervisor.sh` 用 jq 解析状态文件（**必需**）；`api-dispatch.sh` 没有 jq 会自动 fallback 到 python3。
- 所有脚本通过 `source ~/.config/ai-keys/*.env` 读取 key，**密钥只在你本地，不在本仓库**。

---

## License

MIT © GiaSip
