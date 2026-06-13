# Model Roster

> Model names and versions evolve with vendor updates. Check vendor docs before calling.

## API Direct Call Models

| Parameter | Model | Key File | Context | API Endpoint | Best For |
|-----------|-------|----------|---------|-------------|----------|
| `deepseek` | DeepSeek V4-Pro (thinking mode on) | `deepseek.env` | 1M | api.deepseek.com | Causal chain reasoning, numerical verification, hypothesis testing |
| `qwen` | Qwen3.6 Plus (Tongyi) | `dashscope.env` | 1M | dashscope.aliyuncs.com (compat mode) | Information synthesis, long document processing, structured output |
| `glm` | GLM-5.1 (Zhipu flagship) | `zai.env` | 200K | open.bigmodel.cn | Fact-checking, low hallucination rate, claim verification |
| `doubao` | Doubao Seed-2.0 Pro (ByteDance) | `volcengine.env` | 256K | ark.cn-beijing.volces.com | Chinese expression, writing quality |
| `minimax` | MiniMax M2.7 | `minimax.env` | — | api.minimax.io | Programming tasks, Office document processing |

## CLI Models

| CLI | Model | Best For |
|-----|-------|----------|
| Codex | GPT-5.5 (xhigh reasoning) | Code review, architecture analysis, deep reasoning |
| Gemini | gemini-3.1-pro-preview (1M context) | Vision/PDF parsing, large context tasks, broad knowledge |
| Kimi | K2.6 (Chinese-native thinking model) | Chinese business analysis, strategic assessment, creative writing |

## Multi-Dispatch Lineup Recommendations

| Task Type | Lineup | Rationale |
|-----------|--------|-----------|
| Chinese business/strategic analysis | Kimi + DeepSeek + Doubao | Find blind spots + deconstruct logic + Chinese expression |
| Brand creative/slogan/copywriting | Gemini + Doubao + Kimi | Creative divergence + phonetics + review |
| English technical problems | Codex + Gemini + Kimi | GPT reasoning + Google context + diverse perspective |
| Tech selection/architecture design | Codex + Gemini + DeepSeek | Three different technical judgment systems |
| General/mixed problems | Codex + Gemini + Kimi | Top-tier across three platforms, maximize perspective diversity |
| Ultra-long documents (>100 pages) | Any lineup above + Qwen | Add 1M context processing capability |

Selection principle: **cognitive diversity > quantity**. Pick the smartest, most distinctive models — don't pad the roster. Always use each model's highest-tier configuration; control cost by controlling frequency, not by downgrading per-call quality.
