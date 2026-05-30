---
name: dispatch
description: 多模型调用器 — 把任务或 prompt 派发给其他 AI 模型（Codex / Gemini / Kimi / DeepSeek / 豆包 / Qwen / GLM / MiniMax）执行并取回结果。当你想用某个或某几个其他模型跑任务、需要多模型交叉对比验证、或想用更便宜的模型省钱时触发。提供两类调用通道：API 直调（只需 API key）和 CLI 调用（需本地装对应 CLI）。触发信号：「用 Kimi/Codex/Gemini 跑一下」「交给其他 AI」「换个模型试试」「让几个模型都看看」「这个不用最贵的模型」。
---

# /dispatch — 多模型调用器

把一个任务或 prompt 派发给其他 AI 模型执行，取回结果。这个 skill **只提供调用能力**——选哪个模型、单派还是多派，由你（或当前的 Claude）根据任务临场判断，本 skill 不内置选型偏好。

## 两类调用通道

| 通道 | 模型 | 前提 |
|------|------|------|
| **API 直调**（curl，最快） | DeepSeek / Qwen / GLM / 豆包 / MiniMax | 只需在 `~/.config/ai-keys/` 放对应 `.env`（含 API key） |
| **CLI 调用** | Codex / Gemini / Kimi | 需本地安装并登录对应 CLI |
| **内部 SubAgent** | Claude Haiku / Sonnet | Claude Code 自带，无需外部依赖 |

> 纯思考/分析类任务（不需要读文件、执行命令、改代码）优先走 **API 直调**——比 CLI 快约 10 倍。需要 Agent 能力（操作文件系统、执行命令、改代码）才走 CLI。

---

## 通用纪律（所有 CLI 调用必读）

1. **用 heredoc 传 prompt** —— 避免引号 / 特殊字符问题。
2. **所有 CLI 调用加 `</dev/null`** —— Claude Code 的 Bash 环境中 stdin 是永不关闭的管道，不加会导致 CLI 卡死在等待 stdin。
3. **构造 prompt 时**：简洁明确；不要塞入 Claude Code 专有概念（skills / hooks / SubAgent）；中文任务用中文 prompt，英文任务用英文 prompt；涉及具体项目时补必要上下文。

---

## 调用方式

### API 直调（DeepSeek / Qwen / GLM / 豆包 / MiniMax）

不需要 Agent 能力的纯分析任务，直接调 API。通用脚本：

```bash
~/.claude/skills/dispatch/scripts/api-dispatch.sh --model <model> "$(cat <<'EOF'
prompt 内容
EOF
)"
```

长文本用 stdin：

```bash
echo "长文本内容" | ~/.claude/skills/dispatch/scripts/api-dispatch.sh --model <model> --stdin
```

支持的模型（参数 / key 文件 / 端点均为调用所需，模型名与上下文随各家更新自行调整）：

| 参数 | 模型 | Key 文件 | 上下文 | API 端点 |
|------|------|---------|--------|---------|
| `deepseek` | DeepSeek（思考模式默认开） | `deepseek.env` | 1M | api.deepseek.com |
| `qwen` | 通义千问 Plus | `dashscope.env` | 1M | dashscope.aliyuncs.com（兼容模式） |
| `glm` | 智谱 GLM | `zai.env` | 200K | open.bigmodel.cn |
| `doubao` | 字节豆包 Seed | `volcengine.env` | 256K | ark.cn-beijing.volces.com |
| `minimax` | MiniMax | `minimax.env` | — | api.minimax.io |

> 各 `.env` 文件格式见 README。模型名称（如 `deepseek-v4-pro` / `doubao-seed-2-0-pro-260215`）会随版本更新，调用前可查各家最新文档。

### Codex CLI（OpenAI）— 通过 App Server 协议直连，无冷启动

只读模式（分析 / review / 调研）：

```bash
node ~/.claude/skills/dispatch/scripts/codex-appserver.mjs --effort xhigh "$(cat <<'EOF'
prompt 内容
EOF
)" </dev/null
```

写模式（改代码 / 修 bug / 写测试 / 生成文件）：

```bash
node ~/.claude/skills/dispatch/scripts/codex-appserver.mjs --effort xhigh --sandbox full "$(cat <<'EOF'
prompt 内容
EOF
)" </dev/null
```

**写模式安全规则：**
- 仅在 git 管理的项目目录中使用（`--cwd /path/to/project`）
- 执行完成后必须提醒用户 `git diff` 检查变更；不满意 `git checkout .` 回退
- 涉及生产代码 / 数据库 / 部署脚本时，降级为只读模式 + 输出建议

**注意：**
- `--sandbox` 默认 `read-only`；写模式用 `full`（脚本另支持 `workspace-write` / `danger-full-access` 等高级值）
- 脚本已内置非 ASCII 路径自动 symlink 绕行（`--cwd` 含中文等字符时自动在 `/tmp` 建临时 symlink，退出清理）
- 不要加 `2>/dev/null`——脚本在 stderr 输出结构化进度和错误信息
- 长文本可用 stdin：`echo "长文本" | node ~/.claude/skills/dispatch/scripts/codex-appserver.mjs --stdin --effort xhigh`

### Gemini CLI（Google）— 推荐走 supervisor 脚本

supervisor 内置智能 retry / fallback chain / circuit breaker / timeout / 日志：

```bash
~/.claude/skills/dispatch/scripts/gemini-supervisor.sh --cwd "/path/to/work/dir" "$(cat <<'PROMPT_END'
prompt 内容
PROMPT_END
)"
```

**Supervisor 默认行为：**
- Fallback chain：高配模型 → GA 稳定版 → flash 版（任一不可用自动跳下一个）
- 错误分类：429 短期拥塞 backoff + jitter 重试；日 quota 耗尽立即跳下一个模型；503 走相同 backoff 路径
- 全局 attempt budget 6 次；单模型 hard timeout 600s（可改 `GEMINI_MODEL_TIMEOUT`）
- Circuit breaker：单模型连续 3 次失败进 30 分钟 cool-down
- 日志 `~/.cache/dispatch/gemini.log`（JSONL）+ 状态 `~/.cache/dispatch/gemini-state.json`

**指定单一模型（不走 fallback）：** `~/.claude/skills/dispatch/scripts/gemini-supervisor.sh --model <model-id> "prompt"`
**stdin 模式（长 prompt 推荐）：** `cat prompt.txt | ~/.claude/skills/dispatch/scripts/gemini-supervisor.sh --stdin --cwd "/work/dir"`

**Gemini 视觉 / PDF 解析**（Gemini 原生支持 PDF + 图片视觉解析，是处理无文字层 PDF / 截图的标准路径）：

```bash
~/.claude/skills/dispatch/scripts/gemini-supervisor.sh \
  --cwd "/path/to/files/dir" \
  "$(cat <<'PROMPT_END'
请完整解析 xxx.pdf 的所有页面内容，输出 markdown 格式：
- 保留所有数据表格（用 markdown 表格语法）
- 保留所有规格、技术参数、型号
- 标注页码（## Page 1 / ## Page 2 ...）
- 不要省略任何技术细节
PROMPT_END
)" > output.md
```

适用：PDF 图册（无文字层）、扫描件、产品样本、截图分析、图片 OCR、图表数据提取。输出大文件时建议管道写盘（`... > output.md`），避免长输出截断 stdout。

### Kimi CLI（月之暗面）— 推荐走封装脚本，自动 endpoint 路由

```bash
# 默认：走 Moonshot 通用 endpoint（api.moonshot.cn/v1, MOONSHOT_API_KEY）
~/.claude/skills/dispatch/scripts/kimi-dispatch.sh "$(cat <<'EOF'
prompt 内容
EOF
)"

# Opt-in coding endpoint（kimi CLI + api.kimi.com/coding/v1, KIMI_API_KEY）
KIMI_FOR_CODING=1 ~/.claude/skills/dispatch/scripts/kimi-dispatch.sh "prompt"
```

| Endpoint | 特点 | 适合 |
|---|---|---|
| **默认 Moonshot 通用** | reasoning 可见、保留追问倾向 | 通用分析、综合问答 |
| `KIMI_FOR_CODING=1` | 输出体量更大、自带 agent harness、reasoning 不可见 | 长篇报告、agent 自主写文件、多步骤代码 |

### Claude Code 内部 SubAgent（不走外部 CLI）

简单任务用 Haiku、标准任务用 Sonnet 时，直接用 Agent 工具派 SubAgent（指定 `model: haiku` 或 `model: sonnet`）——比 headless CLI 更快更便宜，且无外部依赖。

---

## 环境检查

调用前快速确认可用工具：

```bash
# CLI 工具
command -v codex; command -v gemini; command -v kimi

# API key（用于 API 直调）
ls ~/.config/ai-keys/*.env 2>/dev/null
```

只派可用的模型。CLI 不可用时切到 API 直调或换模型；API key 存在即可调用对应模型。

---

## 多模型并行（交叉对比 / 多方验证）

需要多个模型对同一问题给出独立视角时，**并行发出多个 Bash 调用**即可，最后由 Claude 综合对比。典型场景：重要决策、技术选型、不可逆操作前的交叉验证、对单一模型结果不放心。

```bash
# 三路并行示例（同一 prompt 发给三个模型）
~/.claude/skills/dispatch/scripts/kimi-dispatch.sh "分析任务" &
~/.claude/skills/dispatch/scripts/api-dispatch.sh --model deepseek "分析任务" &
~/.claude/skills/dispatch/scripts/api-dispatch.sh --model doubao "分析任务" &
wait
```

选阵原则：认知多样性 > 数量——选训练数据 / 架构差异大的模型，得到的视角才真正不同；始终用各模型最高配置，控成本靠控频率而非降单次质量。

---

## 执行参数

- **Bash timeout：**
  - Codex 深度推理（xhigh）：`600000`（10 分钟，Bash 工具上限，与脚本默认 600s 对齐）
  - Gemini / Kimi 单派：`240000`（4 分钟）；多派每路 `300000`（5 分钟）
- 单派 = 一个 Bash 调用；多派 = 多个 Bash 调用并行发出
- Codex 走 App Server 协议直连无冷启动，xhigh 深度推理通常 3-8 分钟
- Gemini / Kimi 走 CLI headless 模式，保留 `2>/dev/null`

## Fallback 链

```
首选通道失败（超时 / 报错）
→ 尝试备选模型（同类能力）
→ 备选也失败
→ 降级为"仅推荐"模式：输出建议方案但不执行，交还用户
```

---

## 输出格式

**单派：**

```markdown
## 任务执行结果
**执行者：** [模型名]　**任务：** [一句话复述]

### 结果
[模型输出]

### 执行信息
- 耗时：[X 秒]　状态：[成功 / 部分成功 / 失败]
```

**多派：**

```markdown
## 任务执行结果（多派）
**任务：** [一句话复述]

### [模型 1] 的方案
[核心要点 3-5 条]

### [模型 2] 的方案
[核心要点 3-5 条]

### 综合分析
- **共识：** [各方一致的部分]
- **分歧：** [不同点，标注各方立场]
- **我的判断：** [Claude 作为调度员的独立评估]
```

---

## 脚本清单

| 脚本 | 作用 |
|------|------|
| `~/.claude/skills/dispatch/scripts/api-dispatch.sh` | API 直调（DeepSeek / Qwen / GLM / 豆包 / MiniMax）|
| `~/.claude/skills/dispatch/scripts/codex-appserver.mjs` | Codex App Server 协议直连（只读 / 写模式）|
| `~/.claude/skills/dispatch/scripts/gemini-supervisor.sh` | Gemini CLI 调用 + retry / fallback / circuit breaker |
| `~/.claude/skills/dispatch/scripts/kimi-dispatch.sh` | Kimi 调用 + endpoint 路由 + API fallback |

> 安装、依赖、API key 配置见 README.md。
