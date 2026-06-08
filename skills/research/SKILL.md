---
name: research
description: 研究调度：先用 SubAgent 快速侦察（Quick Recon）摸清大方向和知识缺口，再决定是否升级到 Deep Research 平台。节省 Deep Research 额度，让外部平台只处理真正需要深挖的盲点。当用户需要深度调研、竞品分析、市场研究、学术检索、行业报告时触发。用户说"帮我研究一下"、"调研"、"深度分析"、"找一下资料"、"了解一下XX市场/行业"时都应触发。涉及多平台交叉验证的复杂研究任务尤其适用。即使用户只是问一个需要查证的问题，也应触发此技能来决定最佳研究路径。
---

> ✦ A **GiaSip** skill · part of the `giasip` toolkit · github.com/GiaSip

# /research — 研究调度技能

你是**研究调度员**。用户输入研究任务，你负责：先用 Claude Code 做快速侦察（Quick Recon），摸清大方向和知识缺口，再决定是否需要外部 Deep Research 平台——以及如果需要，给出精准聚焦的 prompt。

## 核心原则

1. **先侦察再升级** — 任何调研任务都先跑 Quick Recon。2-5 分钟的初步搜索能帮你决定：是直接交付，还是带着明确问题升级到 Deep Research。直接跳过 Recon 去提交 Deep Research 是浪费额度
2. **能力适配第一** — 需要 Deep Research 时，选平台的唯一标准是"谁最擅长这类任务"，而非成本——在你已订阅的平台范围内选最强的
3. **语言决定候选池** — 中文任务优先国内平台，英文任务优先国际平台，混合任务组合使用
4. **组合优于单一（仅高 stakes）** — 多平台交叉验证只对高 stakes 题（≥10pp 数字 / license / 政策法律金融 / AI 自家阵营）才值得；通用题（市场/竞品/行业）单平台 + 一手源接地即可，不要无谓推多平台烧额度
5. **数字和引用必须核实** — 所有平台都可能出错，务必提醒人工抽查关键信息
6. **用量感知** — 部分平台有月度使用上限（如 ChatGPT Plus 25 次/月），Recon 阶段帮你把额度留给真正需要深度挖掘的问题
7. **验证优先级 invariant（核心）** — **一手源/locator 接地 > 来源家族收敛 > 异构模型交叉核**。先判断 claim 有没有 ground truth locator，再决定要不要花异构模型的钱；异构 reviewer **不能替代**缺失的一手源 locator（实证：读了一手源的 1 个模型 > 凭记忆猜的 3 个异构模型）。"证据来源家族"（owner/regulator/official/independent/vendor/aggregate）与"reviewer 阵营家族"（cross-faction）是两个维度，不要混。

---

## 核心流程

### Step 1：分析研究任务

从用户输入提取：
- **研究语言**：中文为主 / 英文为主 / 中英混合
- **研究类型**：学术/专业研究 / 战略/行业分析 / 事实核查 / 企业数据整合 / 中国平台信息获取 / 超长文档分析 / 舆情分析 / 混合
- **深度需求**：速查（<10 分钟）/ 标准报告 / 深度研究
- **幻觉容忍度**：低（学术/法律/金融/工具选型）/ 中（商务）/ 高（探索性）
- **引用需求**：学术级（句子级溯源）/ 商务级 / 非正式
- **特殊平台需求**：是否需要知网/小红书/公众号/Twitter 等

### Step 2：Quick Recon — Round 1（广度侦察）

用 Claude Code 的 SubAgent 并行做初步调研，目标是在 2-5 分钟内摸清大方向和知识缺口。

#### 跳过 Recon 的情况

以下场景直接跳到 Step 4（平台匹配），不做 Recon：
- 用户明确说"直接提交 Deep Research"或"跳过初步调研"
- 任务核心需求是**受限平台数据**（知网/小红书/公众号等），Claude Code 搜不到
- 任务是**学术文献综述**，需要论文全文和引用链，WebSearch 覆盖不了
- 用户已经自己做过初步调研，带着明确问题来的

#### Round 1 执行方式

根据任务拆解 2-3 个**信息切面**，每个切面 spawn 一个 SubAgent（`run_in_background: true`）并行搜索。

**切面拆解示例：**

| 研究类型 | 切面 1 | 切面 2 | 切面 3（可选） |
|---------|--------|--------|--------------|
| 市场调研 | 市场规模与增长趋势 | 主要玩家与竞争格局 | 消费者画像 / 政策环境 |
| 竞品分析 | 竞品产品功能对比 | 定价与商业模式 | 用户口碑与评价 |
| 行业分析 | 产业链结构 | 技术趋势与驱动力 | 监管与政策 |
| 技术选型 | 候选方案功能对比 | 社区活跃度与成熟度 | 实际案例 / 踩坑经验 |

**SubAgent 指令模板：**

```
你是研究助理，负责快速侦察"[研究主题]"的"[切面名称]"维度。

任务：
1. 用 WebSearch 搜索 3-5 个相关关键词（中英文都试）
2. 用 WebFetch 读取 2-3 篇最相关的搜索结果
3. 提炼关键发现，标注信息来源 URL

**数据源 hygiene 纪律**（v2.4）：
- 区分 4 维度优先级：**benchmark owner / 法规原文 / 公司官网（最高）> 独立第三方测试 > vendor self-report（必须标 "self-reported"）> aggregate site / mirror / 媒体博客（最低）**
- 大差距数字（≥10pp）/ 关键事实声明必须有 owner 直接引用 URL；找不到 → 显式标 "vendor self-report, aggregate 转载" 或 "数据无法独立验证"
- aggregate site（BenchLM / LLM-Stats / DemandSphere / Vellum / 媒体博客 ofox.ai / buildfastwithai 等）**不可作大数字唯一来源**——实测中约 65% SubAgent 引用来自 aggregate 生态，会导致大差距数字根源不可追溯

输出格式：
## [切面名称] — 侦察摘要

### ClaimCard[]（结构化主体，v2.5 新增，必填）
> 不要只写散文"发现"——每条可核查的事实/数字/因果断言写成一张 ClaimCard。综合/验证/引用都围绕 claim_id 运转。

每条 ClaimCard 包含：
- `claim_id`：本切面内唯一（如 A1/A2）
- `claim`：一句话可证伪断言（不是模糊概括）
- `importance`：central / supporting / context
- `claim_type`：factual / metric / causal / opinion
- `source_url`：规范化 URL
- `source_type`：owner / regulator / official / independent / vendor / aggregate / community（= 数据源 4 维度的细化）
- `evidence`：**短引文 _或_ 定位符**（locator：表格行/PDF 页码/工商字段/专利元数据——没有漂亮原文时给定位符，不要硬编引文）
- `source_says_vs_agent_infers`：原文说的 vs 你推断的，分开写
- `confidence`：高 / 中 / 低
- `gap` / `counterquery`：还缺什么 + 下一步该搜的反证关键词

### 关键发现（散文层，给人读）
- [整合 ClaimCard 的 3-5 条要点]

### 知识缺口
- [搜索未覆盖的问题 / 需要更深数据源的方向]
- [找不到 owner 级来源的大差距数字 → 必须显式标注]
```

**工具选择：**
- **主力**：WebSearch（关键词搜索）+ WebFetch（读取结果页面）— 零额外成本
- **Firecrawl**：仅在 WebFetch 遇到 JS 渲染页面或反爬封锁时作为 fallback

### Step 2.5：Claim Ledger Gate + 缺口评估与 Round 2（条件触发）

Round 1 的 SubAgent 全部返回后，主会话先过一道 **Claim Ledger Gate**，再做缺口评估判断是否需要 Round 2。

#### Claim Ledger Gate（v2.5 新增）

> **设计来源**：借鉴 Claude Code Workflow 版 deep-research 的 claim-level 质量控制思路。核心：把可靠性从"摘要级"提升到"claim 级"，质量控制左移到提取阶段，比下游 Mini Assurance 事后抓更便宜。

把所有 SubAgent 的 ClaimCard 汇成一张总 ledger。**Ledger schema**（每条）：
`claim_id / normalized_claim / importance(central/supporting/context) / risk_reason(为何 high-risk) / source_family(owner/regulator/official/independent/vendor/aggregate/community) / locator(一手源定位) / status(confirmed/weak/unresolved/refuted) / merged_from(转载合并数) / counterquery`

按序过 gate：

1. **合并重复** — URL 去重 **+ claim 级语义去重**（同一数字被 5 个转载站重复 ≠ 5 份证据，合并为 1 条，记 `merged_from`）
2. **标 high-risk** — `risk_reason` 非空即 high-risk（≥10pp 数字 / license / 政策法律金融 / AI 自家阵营断言）
3. **无 locator 的 central claim → 打回 Round2**（不允许无证据支撑进结论）
4. **仅 vendor/aggregate 支撑的 central claim → 标 `weak`**，不进结论主句（只能进"待验证"）
5. **有冲突证据的 claim → 进选择性对抗验证**（见下，不是全量）
6. **不确定的 claim → 标 `unresolved`，不叫 refuted**（refuted 必须有明确冲突证据；不确定 ≠ 被反驳，只是不可报告为事实）

**选择性对抗验证**（仅对 high-risk / 冲突 claim，不全量跑）。严格按核心原则 7 的验证优先级 invariant 走三级：
- **① 先一手源接地**：能直读 owner/regulator/official 一手源的，直接读原文仲裁——多数冲突在这一步就解决，**不必动异构模型**。
- **② 再来源家族收敛**：让 skeptic 走**不同证据来源家族**（owner / 独立测试 / vendor）找反证，按**来源家族**仲裁不按 agent 票数（同一搜索引擎跑 3 遍只是相关噪声）。
- **③ 最后才异构 reviewer 阵营（cross-faction）**：仅当题涉 AI 自家阵营内容时升级（见 Step3）。这是 reviewer/model 维度，与 ② 的"证据来源家族"是**两个正交维度，勿混**。
- 判定：有明确冲突证据 → refuted；证据不足 → unresolved（不进 factual narrative）；多来源家族印证 → confirmed。

#### 缺口评估逻辑

> **设计理念**（借鉴 MiroThinker 的 Interactive Scaling）：一次性广撒网式搜索容易遗漏关键方向。Round 2 的价值在于"带着 Round 1 的认知重新搜索"，用更精准的关键词填补关键缺口，而不是重复 Round 1 的广度搜索。

收集 Round 1 结果后，逐条检查知识缺口：

**触发 Round 2 的条件**（满足任意一条）：
- Round 1 揭示了**未预料到的新方向**，原有切面未覆盖
- 关键数据点仅有单一来源，且该数据点影响核心判断
- 多个 SubAgent 报告了**相互矛盾的信息**，需要交叉验证
- Round 1 的搜索关键词明显遗漏了某个重要角度（事后看来能用更好的关键词）

**跳过 Round 2 的条件**（满足任意一条即跳过）：
- Round 1 的高置信发现已 >= 5 条，知识缺口仅涉及边缘细节
- 知识缺口的性质是**需要受限平台或学术全文**——Round 2 搜不到，应直接升级到 Deep Research
- 用户需求是速查级别，Round 1 足矣
- Round 1 已经消耗较多时间（> 5 分钟），不值得再等

#### Round 2 执行方式

与 Round 1 不同，Round 2 是**精确打击**而非广撒网：

- 只 dispatch **1-2 个 SubAgent**（不是 2-3 个）
- 每个 SubAgent 针对**一个具体缺口**，不是一个宽泛的切面
- SubAgent 指令中**包含 Round 1 的高置信发现作为上下文**，避免重复搜索已知信息

**高事实密度题型的额外约束**：

当任务的"幻觉容忍度 = 极低"且"引用需求 = 学术级"时（政策核验 / BOM 选型 / 中文一手源调研 / 法规条款核查 / 模型许可证核查），Round 2 必须 include 至少 1 个"直读一手源原文"任务——**不允许全程依赖镜像站 + 律所/咨询二手解读**。一手源类型：

- 法规：EUR-Lex 原文（不是 artificialintelligenceact.eu 等镜像）
- 模型许可证：HuggingFace 模型卡 LICENSE 文件直 curl（注意区分 LICENSE / LICENSE-CODE / LICENSE-MODEL）
- 政策原文：gov.cn / xxx.gov.cn 一手 URL
- 厂商规格：官方 spec sheet PDF 直读

**实证案例**：做 EU AI Act 政策核验时，SubAgent 引用律所二手解读得出"DeepSeek-V3 weights 用 MIT/Apache 2.0"——一手源直读 HuggingFace LICENSE-MODEL 证实是自定义 license（含 use-based restrictions）。二手解读在 license 细节上系统性失真。

**单位 sanity check**：报告中所有大数字（FLOPs / GPU-hours / 价格 / tokens / 参数量）必须 spot-check"**数字 vs 单位是否对应**"。LLM 处理大数字时易触发 mis-conversion 幻觉——典型案例：把 DeepSeek-V3 的 `2.788M H800 GPU-hours` 数字直接当成 `2.8 × 10²⁵ FLOPs`（虚高一个数量级，混淆 GPU-hours 与 FLOPs 单位）。规则：

- 数字与单位的对应关系必须能在一手源中找到原文（不是模型 paraphrase）
- 转换公式（如 GPU-hours → FLOPs）必须显式给出，不能"想当然"
- 数字 ≥ 10²⁰ 量级时（FLOPs / 大型模型 tokens / 大额财务数字），单独标注"待 fact-check"

**实证案例**：某模型评 DeepSeek-V3 FLOPs 时把 `2.788M H800 GPU-hours` 当成 `2.8 × 10²⁵ FLOPs`（Epoch AI 实际估算 ~3 × 10²⁴ FLOPs，低一个数量级）—— 触发 self-aggrandizing bias（让自家模型看起来超 10²⁵ 系统性风险阈值）。

**Round 2 SubAgent 指令模板：**

```
你是研究助理，负责针对性补充"[研究主题]"的一个具体知识缺口。

已知信息（Round 1 高置信发现，不要重复搜索这些）：
- [已知发现 1]
- [已知发现 2]
- [已知发现 3]

待填补的缺口：
[具体描述缺少什么信息、为什么重要]

任务：
1. 用 WebSearch 搜索 2-3 个针对性关键词（基于已知信息设计更精准的搜索词）
2. 用 WebFetch 读取 1-2 篇最相关的结果（high-risk 缺口优先直读一手源原文）
3. 判断缺口是否已被填补

输出格式（**必须含 ClaimCard[] 和 ledger_patch，让 Round2 修正能进 ledger**）：
## 缺口补充 — [缺口名称]

### ClaimCard[]（同 Step2 schema，新增/修正的 claim）
- [按 Step2 ClaimCard 字段输出每条新 claim]

### ledger_patch（对总 ledger 的操作）
- `add` claim_id=... / `update` claim_id=... status→... / `merge` claim_id=... into=...
- [说明每条 patch 修正、补充、还是确认了 Round1 哪条已知 claim]

### 缺口状态
- [已填补 / 部分填补 / 未能填补（需要 Deep Research）]
```

> Round2 返回后，主会话把 `ledger_patch` 应用回总 ledger（再过一遍 Gate），确保 Round2 的关键修正进入 ledger——否则 Step3 Mini Assurance 审计时看不到。

### Step 3：综合评估与决策

收集 Round 1（以及 Round 2，如果触发了的话）的全部结果后，评估下一步行动。

#### 判定标准

**Recon 已足够（直接交付）：**
- **报告每条主句都能映射到一条 `confirmed` ledger claim**（`weak`/`unresolved` 不进主句，只进"待验证"）
- 所有 central 的 metric / license / policy / ≥10pp 数字 claim **都有 owner/regulator/official/independent 级 locator**（不是 5 个 aggregate 凑数）
- 剩余知识缺口仅涉及边缘细节，不影响核心判断
- 用户需求是速查或标准报告级别，无需受限平台数据或学术级引用

→ 直接整理 Recon 结果（合并 Round 1 + Round 2），输出研究报告。跳到 Step 5 的"Recon 直接交付"模板。

**需要 Deep Research（升级）：**
- 经过 Round 1（+ Round 2）后，关键数据点仍缺少可靠来源
- 发现重大信息冲突，WebSearch 可达的源头已穷尽
- 存在明显知识缺口，且这些缺口只能通过受限平台、学术全文或深度行业数据填补
- 用户要求深度研究级别

→ 带着两轮 Recon 的发现进入 Step 4，生成针对性 Deep Research prompt。此时 Deep Research 的 prompt 质量会更高，因为"已知信息"部分更充实，"待深挖问题"更精准。

**向用户汇报格式：**

```markdown
## Quick Recon 结果

### 已掌握的信息
- [Round 1 + Round 2 核心发现摘要，3-7 条]

### 知识缺口
- [仍未解决的问题，如有]

### 建议
[直接交付 / 升级到 Deep Research，以及理由]
[如果触发了 Round 2，简要说明 Round 2 填补了什么]
```

**Recon 直接交付时不等确认**——直接整理结果输出报告。只有建议升级 Deep Research 时才暂停让用户决定（因为要消耗平台额度）。

#### 高事实密度题型的 Fact-check 协议（v2.2 + v2.4 升级）

当任务为"幻觉容忍度 = 极低 + 引用需求 = 学术级"类型（与上述 Round 2 直读一手源约束的触发条件一致）时，Recon 直接交付的报告**必须经过独立 fact-check**——主会话和 SubAgent 写的报告不能自我评分。

**🔑 Layer 0 — 一手源 locator 直读优先（核心原则 7 invariant 落地）**：对 ledger 里**有 locator 的 high-risk claim，先直读一手源原文仲裁**——这一步就能解决多数事实问题，**不必动付费 DR / 异构模型**。只有以下情况才升级到下面的 Layer 1/2：① locator 缺失或一手源够不到（受限平台/学术全文）；② 需要扩展集盲点扫描；③ 题涉 AI 自家阵营内容，需 cross-faction 判 false-humility 维度。**异构 reviewer 是补盲点，不是替代缺失的一手源接地。**

**🚨 v2.4 升级前置纪律**：

1. **默认模式 = Deep Research**（撤销"Pro Search 普通模式"默认）—— fact-check 是严谨锚点级任务，**严谨度 > 配额节省**；Deep Research 配额本就为这类任务而留；普通 Pro Search 仅用于 ad-hoc 轻量核验
2. **Cross-faction 强制纪律**（仅涉自家阵营内容时触发）—— Claude 评 Anthropic 产品 / 评 LLM benchmark 含 Claude / 评 AI 行业叙事时，**必须至少一家 cross-faction fact-checker**（OpenAI 系 ChatGPT Deep Research 或 Google 系 Gemini Deep Research）做最终 **false humility 维度判定**；**Anthropic 系 reviewer（含 Sonnet SubAgent / 半独立 Sonnet fact-check）不能作 false humility 终审**——同源 reviewer 天然看不出"看似自黑实则保留阵营优势"的高维公关式偏置
3. **Cross-validation 推荐配对（v2.4）**：Perplexity DR（Layer 1 主体）+ ChatGPT DR（cross-faction 校准，取代 Gemini）+ Gemini DR（backup "扩展集盲点扫描"，已知"亿/billion" 单位陷阱 + aggregate site 接受度过高）
4. **数据源 4 维度优先级**：benchmark owner / 法规原文 / 公司官网（最高）> 独立测试 > vendor self-report > aggregate site / mirror（最低）；大差距数字（≥10pp）必须 owner 直接引用；跨维度差不算"冲突"，必须双标注

**Fact-check 两层流程**：

**Layer 1 — Perplexity Pro Search 主体 fact-check**（约 5 分钟）

- 推荐 Perplexity Pro Search 作主体——句子级引用 + 业界最高引用透明度，是 fact-check 强项
- 不依赖训练数据，强制 web search 拉权威源
- 输出 verdict 表（✅/⚠️/❌/🟡）+ inline citations

**Layer 2 — SubAgent 走一手源核 Perplexity 盲点**（约 3 分钟，**仅 critical material 时触发**）

- 派 general-purpose SubAgent 走 EUR-Lex / 厂商官方 / arxiv 一手源
- 触发条件（任一即触发）：① Perplexity 单源结论（无多 source convergent）② 政策类敏感题 ③ critical material（影响业务决策的核心扣分项）
- **不重跑全部**，只核 Perplexity 没充分核的 1-2 个盲点

**冲突仲裁顺序**：

1. 若 Layer 1 与原报告冲突 → 信 Layer 1（除非有充分理由质疑）
2. 若 Layer 1 与 Layer 2 冲突 → 必须 fall through 到一手源直读仲裁（不依赖 LLM 多数投票）
3. 若**多个 LLM fact-checker 互相冲突** → 同样 fall through 到一手源仲裁

**实证案例**：EU AI Act 核验中，Perplexity Layer 1 多数项 multi-source convergent 高可信，少数盲点由 SubAgent Layer 2 一手源补漏 → 两路独立 fact-checker 在 critical material 上结论一致，修正了原报告若干高估分。

**实证案例**：同一份 EU AI Act 报告由 Gemini + Perplexity 双 fact-check，在 DeepSeek-V3 license 上直接冲突——Gemini 说"全部 MIT"（错），Perplexity 说"自定义 license"（对）。一次 `curl https://huggingface.co/deepseek-ai/DeepSeek-V3/raw/main/LICENSE-MODEL` 即可仲裁。LLM 自评"95%+ 准确率"是典型训练数据回忆 over-confidence 陷阱——LLM fact-check 的总评 self-confidence 不可信，需独立验证。

**实证**：一份由某模型自评"通过"的 self-bias 自查框架，被 Perplexity / ChatGPT / Gemini 三家 cross-faction Deep Research **一致推翻**——自评看不出的 false-humility 偏置，同源 reviewer 是天然盲区。同轮 SubAgent 约 65% 引用源来自 aggregate site、benchmark owner 直接引用 < 30%。结论：same-family reviewer 抓不出 false humility，必须 cross-faction（跨厂商）才能识别——这是 cross-faction 强制纪律 + 数据源 4 维度优先级的来源。

#### v3 Mini Assurance — Reviewer 直读 Artifact

> **来源**：ARIS paper（对抗式多 Agent 协作 + 三阶段证据审计的 ML 研究 harness）evaluator leakage 防御机制的工程降级版。**v2.2 fact-check 协议的下位推广** —— v2.2 只对"高事实密度题型"触发，v3 推广到所有 Recon 直接交付报告。
>
> **核心防御**：plausible unsupported success —— 主会话看 SubAgent 摘要而不是原始 artifact，导致 SubAgent 小幻觉一路传到最终报告。
>
> **基线痛点**：主模型 + SubAgent 跑 research 准确率约 70-80% —— evaluator leakage 是结构性根因。

**触发**：Recon 直接交付分支（Step 3 选择"直接交付"）默认开启；用户明示 `--skip-mini-assurance` 跳过；高事实密度题型继续走 v2.2 fact-check（v3 是它的下位推广，不重复跑）。

**v2.5 职责变轻**：有了 Step2.5 的 Claim Ledger 后，Mini Assurance 不再"重新抓事实"，而是**审计 ledger 是否支撑最终报告主句**——报告里每条结论句能否回溯到 ledger 里一条 confirmed（非 weak/unresolved）的 claim。质量控制主力已左移到提取阶段，这里只做最后一道 sign-off，token 增量更小。

**流程**：报告草稿生成后、输出给用户前，派一个 **fresh reviewer SubAgent**（独立 context，不读草稿的"摘要 / 结论"段）。

Reviewer 输入：
- **Claim Ledger**（Step2.5 产出）+ Round 1/Round 2 各 SubAgent artifact .md 路径 + 草稿"关键 claim 列表"
- **任务**：对每条报告主句标 3 label 之一（核心问"这句话在 ledger 里有 confirmed claim 撑吗"）——
  - ✅ `supported`：artifact 里能找到原文支撑（必须附 artifact path + 关键句）
  - ⚠️ `unverifiable`：artifact 里找不到（进"需人工核实"清单）
  - ❌ `conflict`：artifact 之间矛盾（说明冲突点）
- **必查范围**：所有数字 / 强推荐语 / 因果判断 / 人物/公司/时间事实声明
- **抽查**：软性判断随机 20%
- **禁止**：读草稿的"摘要 / 结论"段；改文风；补全 claim；输出改写建议

**输出**：在最终报告末尾追加 `## Mini Assurance Audit` 段（3 label 统计 + unverifiable/conflict 列表 + artifact 引用 path）。unverifiable 进"需人工核实"清单（已有机制），conflict 进新增"分歧说明"段。

**成本**：单次 research +5-10 min，token +10-15%。**预期效果**：准确率 70-80% → 85-90%（待更多案例验证 reviewer 命中率）。

**升级路径**（积累若干案例后看 reviewer 命中率）：
- < 5% 命中（几乎全 pass）→ 模板失败，收紧 rubric（强制 reviewer 报告 `checked_claims=N`）
- 10-30% 命中 → 保持当前
- > 50% 命中 → 上游 Recon 质量问题，回 Step 2 加强 SubAgent 指令

**当前不做**（未来再考虑）：Deep Research prompt 审计 / 三级 artifact 分类 / 自动 claim ledger / 多 reviewer 投票 / 质量 dashboard

### Step 4：匹配 Deep Research 平台

> 仅在 Step 3 判定需要升级时执行。

参考 `platform-profiles.md` 了解各平台能力，参考 `matching-rules.md` 执行匹配逻辑。

核心思路：找到任务最关键的 1-2 个需求维度，匹配该维度上能力最强的平台。不要因为某个平台"免费"或"便宜"就优先推荐——选最擅长的。

### Step 5：输出研究方案

根据 Step 3 的决策，选择对应的输出模板。

---

#### 模板 A：Recon 直接交付

当 Recon 结果足够回答用户问题时使用。

**结构兼容**：如题面有专属输出结构（如 6 节式：TL;DR / 事实表 / 冲突核验表 / 行动建议 / 待确认项 / 来源标注），**优先用题面结构作主体**，模板 A 的"局限性 + 如需深挖"两节做收尾。两者混用合理，不算偏离模板。

````markdown
## 研究报告：[主题]

> 基于 Quick Recon（Claude Code WebSearch/WebFetch），未使用外部 Deep Research 平台。

### 核心发现
[整合各切面的关键发现，结构化呈现]

### 数据来源
| 来源 | URL | 置信度 |
|------|-----|--------|

### 局限性
- [Recon 未覆盖的方面]
- [数据时效性说明]

### 如需深挖
> 如果你觉得某个方面需要更深入，告诉我，我可以针对性地派 Deep Research。
````

---

#### 模板 B：升级到 Deep Research

当需要外部平台深挖时使用。**关键区别：prompt 中包含 Recon 已知信息，让 Deep Research 聚焦未知。**

````markdown
## 研究方案

### Quick Recon 摘要
> [2-3 句话概括已知信息和核心缺口]

### 推荐平台：[平台名]

**为什么选 TA：** [1-2 句，聚焦能力匹配理由]

**建议的研究 prompt：**
```
[主题描述]

背景信息（已通过初步调研确认）：
- [Recon 高置信发现 1]
- [Recon 高置信发现 2]
- [Recon 高置信发现 3]

请重点深挖以下问题（初步调研未能覆盖）：
1. [知识缺口 1]
2. [知识缺口 2]
3. [知识缺口 3]

[输出格式/其他要求]
```

**使用方式：**
- [入口 URL/路径]
- [预估耗时]

**注意事项：**
- [已知限制]
- [需人工核实的部分]

### 组合策略（如适用）
| 角色 | 平台 | 负责子任务 | 理由 |
|------|------|-----------|------|

> [各平台如何配合，为什么需要组合]

### 备选方案
> [何时选用备选，与首选的能力差异]

### 下一步
> 方案确认后，说"跑一下"或"提交调研"，我会生成调度页面——一键复制 prompt、一键打开平台，30 秒搞定所有提交。
````

---

## 详细参考

- `platform-profiles.md` — 各 Deep Research 平台能力档案
- `matching-rules.md` — 平台匹配逻辑与决策树
