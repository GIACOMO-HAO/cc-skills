# giasip-skills

> ✦ GiaSip 的 [Claude Code](https://claude.com/claude-code) 自定义技能集 · github.com/GiaSip

| 技能 | 说明 |
|------|------|
| **giasip-research** | 研究调度 — 先用 SubAgent 快速侦察（Quick Recon）摸清方向和知识缺口，再决定是否升级到外部 Deep Research 平台。内置两轮 Recon、Claim Ledger 质控、独立 fact-check 协议，让外部平台只处理真正需要深挖的盲点。 |
| **giasip-dispatch** | 多模型调用器 — 把任务或 prompt 一键派发给其他 AI 模型（Codex / Gemini / Kimi / DeepSeek / 豆包 / Qwen / GLM / MiniMax）执行并取回结果。纯调用器形态，不内置选型偏好（选哪个模型、单派多派交给你自己的 Claude 临场判断）。 |

## 安装

### 方式一：`npx skills add`（推荐，一行装）

```bash
# 安装全部技能（全局，装到 ~/.claude/skills/）
npx skills add GiaSip/giasip-skills -g --all

# 只装某一个
npx skills add GiaSip/giasip-skills -g --skill giasip-research

# 先看看仓库里有哪些技能
npx skills add GiaSip/giasip-skills -l
```

### 方式二：作为 Claude Code plugin

```
/plugin marketplace add GiaSip/giasip-skills
/plugin install giasip-skills@giasip-skills
```

### 方式三：git clone

```bash
git clone https://github.com/GiaSip/giasip-skills
cp -R giasip-skills/skills/giasip-research ~/.claude/skills/giasip-research
cp -R giasip-skills/skills/giasip-dispatch ~/.claude/skills/giasip-dispatch
```

> 三种装法触发命令都是 `/giasip-research`、`/giasip-dispatch`（署名焊在技能名上，不依赖安装方式），也可直接描述意图（如「帮我调研一下…」「用 Kimi 跑一下…」）自动触发。脚本路径用 `${CLAUDE_SKILL_DIR}` 自动定位，装在 `~/.claude/skills/` 还是 plugin 缓存目录都能正确解析。

---

## giasip-research — 依赖

**基本零外部依赖，开箱即用**——主要用 Claude Code 自带的 WebSearch / WebFetch / SubAgent（WebFetch 遇 JS 渲染页面时可选用 Firecrawl 作 fallback，非必需）。

唯一需配置：`skills/giasip-research/platform-profiles.md` 里有一张「平台可用性」表，按你实际订阅的 Deep Research 平台（ChatGPT / Gemini / Perplexity / Kimi 等）填 ✅/❌，匹配逻辑会据此跳过未订阅的平台。

## giasip-dispatch — 依赖

两类调用通道，按需配置：

### 1. API 直调（只需 API key，最快）

支持 DeepSeek / Qwen / GLM / 豆包 / MiniMax。在 `~/.config/ai-keys/` 放对应 `.env` 文件：

| 模型 | 文件 | 内容 |
|------|------|------|
| DeepSeek | `deepseek.env` | `export DEEPSEEK_API_KEY=...` |
| Qwen（通义） | `dashscope.env` | `export DASHSCOPE_API_KEY=...` |
| GLM（智谱） | `zai.env` | `export ZAI_API_KEY=...` |
| 豆包（火山引擎） | `volcengine.env` | `export ARK_API_KEY=...` |
| MiniMax | `minimax.env` | `export MINIMAX_API_KEY=...` |

测试：`${CLAUDE_SKILL_DIR}/scripts/api-dispatch.sh --model deepseek "你好"`

> 具体模型名（如 `deepseek-v4-pro`）写在 `api-dispatch.sh` 的 `case` 分支里，会随厂商版本更新——跑不通时去脚本里改 `MODEL_ID`。

### 2. CLI 调用（需本地装并登录对应 CLI）

| 模型 | 安装 | 登录 |
|------|------|------|
| Codex | `npm i -g @openai/codex` | ChatGPT 账号 |
| Gemini | `npm i -g @google/gemini-cli` | Google 账号 |
| Kimi | `uv tool install kimi-cli`（或仅用 API key） | kimi.com / Moonshot key |

依赖检查：`command -v codex gemini kimi node curl python3 jq`

> 所有脚本通过 `source ~/.config/ai-keys/*.env` 读取 key，**密钥只在你本地，不在本仓库**。

---

## License

MIT © GiaSip
