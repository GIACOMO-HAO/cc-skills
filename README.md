# giasip-skills

> Custom [Claude Code](https://claude.com/claude-code) skills by GiaSip &middot; github.com/GiaSip

| Skill | Description |
|-------|-------------|
| **giasip-research** | Research orchestrator — runs a Quick Recon with SubAgents first to map the landscape and knowledge gaps, then decides whether to escalate to an external Deep Research platform. Built-in two-round Recon, Claim Ledger quality gate, and independent fact-check protocol ensure external platforms only handle what truly needs deep digging. |
| **giasip-dispatch** | Multi-model dispatcher — sends a task or prompt to other AI models (Codex / Gemini / Kimi / DeepSeek / Doubao / Qwen / GLM / MiniMax) and retrieves results. Pure dispatcher — no built-in model preference; which model to use and whether to fan out is left to your Claude's judgment. |

## Installation

### Option 1: `npx skills add` (recommended, one-liner)

```bash
# Install all skills globally (to ~/.claude/skills/)
npx skills add GiaSip/giasip-skills -g --all

# Install a single skill
npx skills add GiaSip/giasip-skills -g --skill giasip-research

# List available skills in this repo
npx skills add GiaSip/giasip-skills -l
```

### Option 2: Claude Code plugin

```
/plugin marketplace add GiaSip/giasip-skills
/plugin install giasip-skills@giasip-skills
```

### Option 3: git clone

```bash
git clone https://github.com/GiaSip/giasip-skills
cp -R giasip-skills/skills/giasip-research ~/.claude/skills/giasip-research
cp -R giasip-skills/skills/giasip-dispatch ~/.claude/skills/giasip-dispatch
```

> All three methods register the same slash commands: `/giasip-research` and `/giasip-dispatch`. You can also trigger them by describing your intent (e.g., "research X for me" or "run this with Kimi"). Scripts use `${CLAUDE_SKILL_DIR}` for path resolution, so they work whether installed under `~/.claude/skills/` or in a plugin cache directory.

---

## giasip-research — Dependencies

**Near-zero external dependencies — works out of the box.** Primarily uses Claude Code's built-in WebSearch / WebFetch / SubAgent. (Firecrawl can optionally serve as a fallback when WebFetch hits JS-rendered pages, but is not required.)

The only setup needed: fill in the platform availability table in `skills/giasip-research/platform-profiles.md` with your actual Deep Research subscriptions (ChatGPT / Gemini / Perplexity / Kimi, etc.) — the matching logic uses this to skip unsubscribed platforms.

## giasip-dispatch — Dependencies

Two types of dispatch channels; configure what you need:

### 1. API direct call (just needs an API key — fastest)

Supports DeepSeek / Qwen / GLM / Doubao / MiniMax. Place the corresponding `.env` file in `~/.config/ai-keys/`:

| Model | File | Content |
|-------|------|---------|
| DeepSeek | `deepseek.env` | `export DEEPSEEK_API_KEY=...` |
| Qwen (Tongyi) | `dashscope.env` | `export DASHSCOPE_API_KEY=...` |
| GLM (Zhipu) | `zai.env` | `export ZAI_API_KEY=...` |
| Doubao (Volcengine) | `volcengine.env` | `export ARK_API_KEY=...` |
| MiniMax | `minimax.env` | `export MINIMAX_API_KEY=...` |

Test: `${CLAUDE_SKILL_DIR}/scripts/api-dispatch.sh --model deepseek "Hello"`

> Specific model names (e.g., `deepseek-v4-pro`) are defined in the `case` branches of `api-dispatch.sh` and may change as vendors release new versions — update `MODEL_ID` in the script if a call fails.

### 2. CLI invocation (requires local install + login)

| Model | Install | Auth |
|-------|---------|------|
| Codex | `npm i -g @openai/codex` | ChatGPT account |
| Gemini | `npm i -g @google/gemini-cli` | Google account |
| Kimi | `uv tool install kimi-cli` (or API key only) | kimi.com / Moonshot key |

Dependency check: `command -v codex gemini kimi node curl python3 jq`

> All scripts read keys via `source ~/.config/ai-keys/*.env` — **your keys stay local and are never in this repo**.

---

## Chinese version

A Chinese version of all documentation is available under [`locales/zh/`](locales/zh/).

## License

MIT © GiaSip
