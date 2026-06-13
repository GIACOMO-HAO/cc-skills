---
name: giasip-research
description: "Research orchestrator: runs a Quick Recon with SubAgents to map the landscape and knowledge gaps, then decides whether to escalate to an external Deep Research platform. Saves Deep Research quota by ensuring external platforms only handle what truly needs deep digging. Triggers on deep research, competitive analysis, market research, academic search, industry reports. Trigger signals: \"research X for me\", \"investigate\", \"deep analysis\", \"find materials on\", \"look into the XX market/industry\". Especially suited for complex research requiring multi-platform cross-validation. Even a simple question needing verification should trigger this skill to determine the best research path."
---

> ✦ A **GiaSip** skill · part of the `giasip` toolkit · github.com/GiaSip

# /research — Research Orchestrator Skill

You are a **research dispatcher**. The user provides a research task; your job is to: run a Quick Recon with Claude Code first to map the landscape and knowledge gaps, then decide whether an external Deep Research platform is needed — and if so, generate a precisely focused prompt for it.

## Core Principles

1. **Recon before escalation** — Every research task starts with Quick Recon. 2-5 minutes of initial search helps you decide: deliver directly, or escalate to Deep Research with clear questions. Skipping Recon to submit Deep Research blindly wastes quota
2. **Capability fit first** — When Deep Research is needed, the only criterion for platform selection is "who is best at this type of task," not cost — within your subscribed platforms
3. **Language determines the candidate pool** — Chinese tasks prioritize domestic platforms, English tasks prioritize international platforms, mixed tasks use both
4. **Combination over single (high-stakes only)** — Multi-platform cross-validation is only worth it for high-stakes questions (≥10pp numbers / licenses / policy-legal-financial / AI same-faction claims); for general topics (market/competitive/industry), a single platform + primary source grounding is sufficient — don't burn quota on unnecessary multi-platform runs
5. **Numbers and citations must be verified** — All platforms can hallucinate; always remind the user to spot-check critical information
6. **Quota awareness** — Some platforms have monthly caps (e.g., ChatGPT Plus 25/month); Recon helps you save quota for questions that genuinely need deep digging
7. **Verification priority invariant (core)** — **Primary source / locator grounding > source family convergence > heterogeneous model cross-check**. First determine whether a claim has a ground-truth locator, then decide whether to spend on heterogeneous models. Heterogeneous reviewers **cannot substitute** for missing primary source locators (empirical: 1 model that read the primary source > 3 heterogeneous models guessing from memory). "Evidence source family" (owner/regulator/official/independent/vendor/aggregate) and "reviewer faction family" (cross-faction) are two dimensions — don't conflate them.

---

## Core Flow

### Step 1: Analyze the Research Task

Extract from user input:
- **Research language**: primarily Chinese / primarily English / mixed
- **Research type**: academic/professional / strategic/industry analysis / fact-checking / enterprise data integration / Chinese walled-garden platform data / ultra-long document analysis / sentiment analysis / mixed
- **Depth requirement**: quick lookup (< 10 min) / standard report / deep research
- **Hallucination tolerance**: low (academic/legal/financial/tool selection) / medium (business) / high (exploratory)
- **Citation requirement**: academic-grade (sentence-level tracing) / business-grade / informal
- **Special platform needs**: whether CNKI / Xiaohongshu / WeChat Official Accounts / Twitter, etc. are needed

### Step 2: Quick Recon — Round 1 (Breadth Reconnaissance)

Use Claude Code's SubAgents to run initial research in parallel, aiming to map the landscape and knowledge gaps within 2-5 minutes.

#### When to Skip Recon

Skip directly to Step 4 (platform matching) in these scenarios:
- User explicitly says "submit to Deep Research directly" or "skip preliminary research"
- The task's core need is **walled-garden platform data** (CNKI / Xiaohongshu / WeChat Official Accounts, etc.) that Claude Code can't reach
- The task is an **academic literature review** requiring full papers and citation chains beyond WebSearch coverage
- The user has already done preliminary research and comes with specific questions

#### Round 1 Execution

Break the task into 2-3 **information facets**, spawn one SubAgent per facet (`run_in_background: true`) for parallel search.

**Facet decomposition examples:**

| Research Type | Facet 1 | Facet 2 | Facet 3 (optional) |
|---------------|---------|---------|---------------------|
| Market research | Market size & growth trends | Key players & competitive landscape | Consumer profile / policy environment |
| Competitive analysis | Feature comparison | Pricing & business models | User reviews & reputation |
| Industry analysis | Value chain structure | Technology trends & drivers | Regulation & policy |
| Tech selection | Candidate feature comparison | Community activity & maturity | Real-world cases / lessons learned |

**SubAgent instruction template:**

```
You are a research assistant responsible for quick reconnaissance on the "[facet name]" dimension of "[research topic]".

Tasks:
1. Use WebSearch to search 3-5 relevant keywords (try both English and Chinese)
2. Use WebFetch to read 2-3 most relevant search results
3. Distill key findings, annotate source URLs

**Data source hygiene discipline (v2.4):**
- Distinguish 4-tier priority: **benchmark owner / regulation text / company official site (highest) > independent third-party test > vendor self-report (must label "self-reported") > aggregate site / mirror / media blog (lowest)**
- Large-gap numbers (≥10pp) / critical factual claims must have owner direct citation URL; if unavailable → explicitly label "vendor self-report, aggregate repost" or "data cannot be independently verified"
- Aggregate sites (BenchLM / LLM-Stats / DemandSphere / Vellum / media blogs like ofox.ai / buildfastwithai) **cannot serve as the sole source for large-gap numbers** — empirically ~65% of SubAgent citations come from the aggregate ecosystem, causing large-gap numbers to be untraceable

Output format:
## [Facet Name] — Recon Summary

### ClaimCard[] (structured body, v2.5 required)
> Don't just write prose "findings" — write each verifiable fact/number/causal assertion as a ClaimCard. Synthesis/verification/citation all revolve around claim_id.

Each ClaimCard contains:
- `claim_id`: unique within this facet (e.g., A1/A2)
- `claim`: one-sentence falsifiable assertion (not a vague generalization)
- `importance`: central / supporting / context
- `claim_type`: factual / metric / causal / opinion
- `source_url`: normalized URL
- `source_type`: owner / regulator / official / independent / vendor / aggregate / community (= fine-grained version of the 4-tier source hierarchy)
- `evidence`: **short quote _or_ locator** (locator: table row / PDF page number / registry field / patent metadata — when no clean quote exists, give a locator instead of fabricating one)
- `source_says_vs_agent_infers`: what the source actually says vs. what you infer — separate them
- `confidence`: high / medium / low
- `gap` / `counterquery`: what's still missing + counter-evidence keywords to search next

### Key Findings (prose layer, for human readers)
- [3-5 bullet points integrating ClaimCards]

### Knowledge Gaps
- [Questions not covered by search / directions needing deeper sources]
- [Large-gap numbers without owner-level sourcing → must be explicitly flagged]
```

**Tool selection:**
- **Primary**: WebSearch (keyword search) + WebFetch (read result pages) — zero additional cost
- **Firecrawl**: only as a fallback when WebFetch hits JS-rendered pages or anti-scraping blocks

### Step 2.5: Claim Ledger Gate + Gap Assessment & Round 2 (Conditional)

After all Round 1 SubAgents return, the main session runs a **Claim Ledger Gate** first, then does gap assessment to decide whether Round 2 is needed.

#### Claim Ledger Gate (v2.5)

> **Design origin**: Inspired by the claim-level quality control approach from Claude Code Workflow's deep-research skill. Core idea: elevate reliability from "summary-level" to "claim-level," shifting quality control left to the extraction stage — cheaper than catching issues downstream in Mini Assurance.

Consolidate all SubAgent ClaimCards into a single ledger. **Ledger schema** (per entry):
`claim_id / normalized_claim / importance(central/supporting/context) / risk_reason(why high-risk) / source_family(owner/regulator/official/independent/vendor/aggregate/community) / locator(primary source locator) / status(confirmed/weak/unresolved/refuted) / merged_from(repost merge count) / counterquery`

Run through the gate in order:

1. **Merge duplicates** — URL dedup **+ claim-level semantic dedup** (the same number reposted by 5 aggregators ≠ 5 pieces of evidence; merge to 1, record `merged_from`)
2. **Flag high-risk** — `risk_reason` non-empty = high-risk (≥10pp numbers / license / policy-legal-financial / AI same-faction assertions)
3. **Central claims without locator → send back to Round 2** (no evidence-free conclusions allowed)
4. **Central claims supported only by vendor/aggregate → mark `weak`**, excluded from conclusion topic sentences (can only appear in "pending verification")
5. **Claims with conflicting evidence → selective adversarial verification** (see below, not full-coverage)
6. **Uncertain claims → mark `unresolved`, not `refuted`** (refuted requires explicit conflicting evidence; uncertain ≠ disproven, just not reportable as fact)

**Selective adversarial verification** (high-risk / conflicting claims only, not full coverage). Strictly follow Principle 7's verification priority invariant through three levels:
- **① Primary source grounding first**: when owner/regulator/official primary sources are directly readable, read the original text to arbitrate — most conflicts resolve here, **no need for heterogeneous models**.
- **② Then source family convergence**: have a skeptic search for counter-evidence across **different evidence source families** (owner / independent test / vendor); arbitrate by **source family**, not by agent vote count (running the same search engine 3 times is just correlated noise).
- **③ Heterogeneous reviewer faction (cross-faction) last**: escalate only when the topic involves AI same-faction content (see Step 3). This is the reviewer/model dimension, **orthogonal to ②'s "evidence source family" — don't conflate**.
- Verdict: explicit conflicting evidence → refuted; insufficient evidence → unresolved (excluded from factual narrative); multi-source-family corroboration → confirmed.

#### Gap Assessment Logic

> **Design philosophy** (inspired by MiroThinker's Interactive Scaling): one-shot broad search tends to miss key directions. Round 2's value lies in "searching again with Round 1's knowledge" using more precise keywords to fill critical gaps, not repeating Round 1's breadth.

After collecting Round 1 results, check knowledge gaps item by item:

**Round 2 triggers** (any one sufficient):
- Round 1 revealed **unexpected new directions** not covered by original facets
- Critical data points have only a single source, and that data point affects core judgment
- Multiple SubAgents reported **contradictory information** requiring cross-validation
- Round 1 search keywords clearly missed an important angle (in hindsight, better keywords were available)

**Skip Round 2 conditions** (any one sufficient to skip):
- Round 1 high-confidence findings ≥ 5, and gaps only involve peripheral details
- Gap nature requires **walled-garden platforms or academic full text** — Round 2 can't reach them; escalate to Deep Research directly
- User's need is quick-lookup level, Round 1 is sufficient
- Round 1 already consumed significant time (> 5 min), not worth more waiting

#### Round 2 Execution

Unlike Round 1, Round 2 is **precision strike**, not broad sweep:

- Dispatch only **1-2 SubAgents** (not 2-3)
- Each SubAgent targets **one specific gap**, not a broad facet
- SubAgent instructions **include Round 1's high-confidence findings as context** to avoid re-searching known information

**Additional constraints for high fact-density task types:**

When the task has "hallucination tolerance = extremely low" AND "citation requirement = academic-grade" (policy verification / BOM selection / Chinese primary source research / regulation clause verification / model license verification), Round 2 must include at least 1 "direct primary source reading" task — **relying entirely on mirror sites + law firm/consulting secondary interpretations is not allowed**. Primary source types:

- Regulations: EUR-Lex original text (not mirrors like artificialintelligenceact.eu)
- Model licenses: HuggingFace model card LICENSE file via direct curl (distinguish LICENSE / LICENSE-CODE / LICENSE-MODEL)
- Policy texts: gov.cn / xxx.gov.cn primary URLs
- Vendor specs: official spec sheet PDF direct reading

**Empirical case**: During EU AI Act policy verification, SubAgents cited law firm secondary interpretations concluding "DeepSeek-V3 weights use MIT/Apache 2.0" — direct reading of HuggingFace LICENSE-MODEL confirmed it's a custom license (with use-based restrictions). Secondary interpretations systematically distort license details.

**Unit sanity check**: All large numbers in the report (FLOPs / GPU-hours / pricing / tokens / parameter count) must be spot-checked for "**number vs. unit correspondence**." LLMs are prone to mis-conversion hallucinations with large numbers — typical case: treating DeepSeek-V3's `2.788M H800 GPU-hours` as `2.8 × 10²⁵ FLOPs` (inflated by an order of magnitude, conflating GPU-hours with FLOPs). Rules:

- Number-unit correspondence must be traceable to the primary source's original text (not a model paraphrase)
- Conversion formulas (e.g., GPU-hours → FLOPs) must be explicitly stated, never assumed
- Numbers ≥ 10²⁰ magnitude (FLOPs / large model tokens / large financial figures) get a standalone "pending fact-check" tag

**Empirical case**: A model evaluating DeepSeek-V3 FLOPs treated `2.788M H800 GPU-hours` as `2.8 × 10²⁵ FLOPs` (Epoch AI's actual estimate ~3 × 10²⁴ FLOPs, one order of magnitude lower) — triggering self-aggrandizing bias (making the model appear to exceed the 10²⁵ systemic risk threshold).

**Round 2 SubAgent instruction template:**

```
You are a research assistant responsible for targeted gap-filling on "[research topic]."

Known information (Round 1 high-confidence findings, do not re-search these):
- [known finding 1]
- [known finding 2]
- [known finding 3]

Gap to fill:
[specific description of what's missing and why it matters]

Tasks:
1. Use WebSearch to search 2-3 targeted keywords (design more precise search terms based on known information)
2. Use WebFetch to read 1-2 most relevant results (high-risk gaps should prioritize direct primary source reading)
3. Determine whether the gap has been filled

Output format (**must include ClaimCard[] and ledger_patch so Round 2 corrections enter the ledger**):
## Gap Supplement — [gap name]

### ClaimCard[] (same schema as Step 2, new/corrected claims)
- [output each new claim per Step 2 ClaimCard fields]

### ledger_patch (operations on the master ledger)
- `add` claim_id=... / `update` claim_id=... status→... / `merge` claim_id=... into=...
- [explain what each patch corrects, supplements, or confirms from Round 1]

### Gap Status
- [filled / partially filled / unfilled (needs Deep Research)]
```

> After Round 2 returns, the main session applies `ledger_patch` back to the master ledger (re-running the gate) to ensure Round 2's critical corrections enter the ledger — otherwise Step 3 Mini Assurance can't see them.

### Step 3: Synthesis & Decision

After collecting all Round 1 (and Round 2, if triggered) results, evaluate next steps.

#### Decision Criteria

**Recon is sufficient (deliver directly):**
- **Every topic sentence in the report maps to a `confirmed` ledger claim** (`weak`/`unresolved` excluded from topic sentences, only in "pending verification")
- All central metric / license / policy / ≥10pp number claims **have owner/regulator/official/independent-level locators** (not 5 aggregate sites padding the count)
- Remaining gaps involve only peripheral details, not affecting core judgment
- User's need is quick-lookup or standard-report level, no walled-garden data or academic-grade citations required

→ Compile Recon results directly (merge Round 1 + Round 2), output research report. Jump to Step 5's "Recon direct delivery" template.

**Need Deep Research (escalate):**
- After Round 1 (+ Round 2), critical data points still lack reliable sources
- Major information conflicts discovered, and WebSearch-reachable sources are exhausted
- Obvious knowledge gaps remain, fillable only through walled-garden platforms, academic full text, or deep industry data
- User requests deep-research level

→ Proceed to Step 4 with both rounds of Recon findings, generate a targeted Deep Research prompt. The prompt quality will be higher because "known information" is richer and "questions to deep-dive" are more precise.

**User briefing format:**

```markdown
## Quick Recon Results

### Information Gathered
- [Round 1 + Round 2 core findings summary, 3-7 items]

### Knowledge Gaps
- [Unresolved questions, if any]

### Recommendation
[Deliver directly / Escalate to Deep Research, with rationale]
[If Round 2 was triggered, briefly explain what it filled]
```

**When delivering from Recon, don't wait for confirmation** — compile results and output the report directly. Only pause for user decision when recommending Deep Research escalation (because it consumes platform quota).

#### Fact-Check Protocol for High Fact-Density Tasks (v2.2 + v2.4 upgrade)

When the task is "hallucination tolerance = extremely low + citation requirement = academic-grade" (same trigger conditions as Round 2 primary source constraint), reports delivered directly from Recon **must undergo independent fact-checking** — the main session and SubAgents' own reports cannot self-score.

**Layer 0 — Primary source locator direct reading first (Principle 7 invariant in practice)**: For high-risk claims in the ledger **that have locators, read the primary source text directly to arbitrate** — this resolves most factual issues and **doesn't require paid DR / heterogeneous models**. Escalate to Layer 1/2 below only when: ① locator is missing or primary source is unreachable (walled-garden / academic full text); ② expansion set blind spot scanning is needed; ③ topic involves AI same-faction content requiring cross-faction false-humility dimension judgment. **Heterogeneous reviewers supplement blind spots; they don't replace missing primary source grounding.**

**v2.4 pre-check discipline:**

1. **Default mode = Deep Research** (reverting "Pro Search normal mode" default) — fact-checking is a rigorous anchor-level task; **rigor > quota savings**; Deep Research quota exists for exactly this type of task; regular Pro Search is only for ad-hoc lightweight verification
2. **Cross-faction mandatory discipline** (triggers only for same-faction content) — When evaluating Anthropic products / LLM benchmarks involving Claude / AI industry narratives, **at least one cross-faction fact-checker must be used** (OpenAI's ChatGPT Deep Research or Google's Gemini Deep Research) for the final **false humility dimension judgment**; **Anthropic-family reviewers (including Sonnet SubAgent / semi-independent Sonnet fact-check) cannot serve as false humility final arbiter** — same-source reviewers are inherently blind to "appears self-deprecating but actually preserves faction advantage" high-dimensional PR-style bias
3. **Cross-validation recommended pairing (v2.4)**: Perplexity DR (Layer 1 primary) + ChatGPT DR (cross-faction calibration, replacing Gemini) + Gemini DR (backup "expansion set blind spot scanning" — known "yi/billion" unit trap + excessive aggregate site acceptance)
4. **Data source 4-tier priority**: benchmark owner / regulation text / company official site (highest) > independent test > vendor self-report > aggregate site / mirror (lowest); large-gap numbers (≥10pp) must have owner direct citation; cross-tier discrepancies are not "conflicts" — both must be annotated

**Fact-check two-layer flow:**

**Layer 1 — Perplexity Pro Search primary fact-check** (~5 min)

- Perplexity Pro Search recommended as primary — sentence-level citation + industry-leading citation transparency is its strength
- Does not rely on training data, forces web search to pull authoritative sources
- Output: verdict table (✅/⚠️/❌/🟡) + inline citations

**Layer 2 — SubAgent primary-source check for Perplexity blind spots** (~3 min, **triggers only for critical material**)

- Dispatch a general-purpose SubAgent to read EUR-Lex / vendor official / arxiv primary sources
- Trigger conditions (any one): ① Perplexity single-source conclusion (no multi-source convergence) ② policy-sensitive topic ③ critical material (core scoring items affecting business decisions)
- **Don't re-run everything**, only check 1-2 blind spots Perplexity didn't fully verify

**Conflict arbitration order:**

1. If Layer 1 conflicts with the original report → trust Layer 1 (unless there's strong reason to doubt)
2. If Layer 1 conflicts with Layer 2 → must fall through to primary source direct reading (don't rely on LLM majority vote)
3. If **multiple LLM fact-checkers conflict with each other** → likewise fall through to primary source arbitration

**Empirical case**: In EU AI Act verification, Perplexity Layer 1 was multi-source convergent and high-confidence on most items; a few blind spots were caught by SubAgent Layer 2 primary source reading → two independent fact-checkers agreed on critical material, correcting several over-scored items in the original report.

**Empirical case**: The same EU AI Act report was fact-checked by both Gemini + Perplexity, which directly conflicted on DeepSeek-V3 license — Gemini said "all MIT" (wrong), Perplexity said "custom license" (correct). One `curl https://huggingface.co/deepseek-ai/DeepSeek-V3/raw/main/LICENSE-MODEL` resolved it. An LLM's self-assessed "95%+ accuracy" is a typical training-data recall over-confidence trap — LLM fact-check aggregate self-confidence scores are not trustworthy and need independent verification.

**Empirical**: A self-bias audit framework self-assessed as "passed" by a model was **unanimously overturned** by Perplexity / ChatGPT / Gemini cross-faction Deep Research — false-humility bias invisible to self-assessment is a natural blind spot for same-source reviewers. In the same round, ~65% of SubAgent citation sources came from aggregate sites; benchmark owner direct citations were < 30%. Conclusion: same-family reviewers can't catch false humility; cross-faction (cross-vendor) is required — this is the origin of the cross-faction mandatory discipline + data source 4-tier priority.

#### v3 Mini Assurance — Reviewer Reads Artifact Directly

> **Origin**: Engineering downgrade of the evaluator leakage defense from the ARIS paper (adversarial multi-agent ML research harness with three-stage evidence audit). **Generalization of v2.2 fact-check protocol** — v2.2 only triggered for "high fact-density tasks"; v3 extends to all Recon direct delivery reports.
>
> **Core defense**: plausible unsupported success — the main session reads SubAgent summaries instead of raw artifacts, allowing SubAgent micro-hallucinations to propagate all the way to the final report.
>
> **Baseline pain point**: main model + SubAgent research accuracy is ~70-80% — evaluator leakage is the structural root cause.

**Trigger**: enabled by default for the Recon direct delivery branch (Step 3 selects "deliver directly"); user can skip with `--skip-mini-assurance`; high fact-density tasks continue using v2.2 fact-check (v3 is its generalization, no double-run).

**v2.5 lighter duty**: With Step 2.5's Claim Ledger, Mini Assurance no longer "re-extracts facts" but **audits whether the ledger supports the final report's topic sentences** — can each conclusion sentence trace back to a `confirmed` (not `weak`/`unresolved`) claim in the ledger. Quality control has shifted left to the extraction stage; this is just the final sign-off, with smaller token overhead.

**Flow**: After the report draft is generated but before output to user, dispatch a **fresh reviewer SubAgent** (independent context, does not read the draft's "summary / conclusions" sections).

Reviewer input:
- **Claim Ledger** (Step 2.5 output) + Round 1/Round 2 SubAgent artifact .md paths + draft's "key claim list"
- **Task**: for each report topic sentence, assign one of 3 labels (core question: "does this sentence have a `confirmed` claim in the ledger backing it?") —
  - ✅ `supported`: artifact contains original text support (must attach artifact path + key sentence)
  - ⚠️ `unverifiable`: not found in artifact (goes to "needs manual verification" list)
  - ❌ `conflict`: artifacts contradict each other (explain conflict point)
- **Mandatory scope**: all numbers / strong recommendations / causal claims / person/company/time factual assertions
- **Spot check**: 20% random sample of soft judgments
- **Prohibited**: reading draft's "summary / conclusions" sections; changing writing style; filling in claims; outputting rewrite suggestions

**Output**: append a `## Mini Assurance Audit` section at the end of the final report (3-label stats + unverifiable/conflict list + artifact reference paths). Unverifiable items go to the existing "needs manual verification" list; conflicts go to a new "Divergence Notes" section.

**Cost**: +5-10 min per research run, +10-15% tokens. **Expected effect**: accuracy 70-80% → 85-90% (pending more cases to verify reviewer hit rate).

**Upgrade path** (after accumulating cases, evaluate reviewer hit rate):
- < 5% hit rate (nearly all pass) → template failure, tighten rubric (force reviewer to report `checked_claims=N`)
- 10-30% hit rate → maintain current approach
- > 50% hit rate → upstream Recon quality issue, go back to Step 2 to strengthen SubAgent instructions

**Not doing now** (future consideration): Deep Research prompt audit / three-tier artifact classification / automated claim ledger / multi-reviewer voting / quality dashboard

### Step 4: Match Deep Research Platform

> Only executed when Step 3 determines escalation is needed.

Refer to `platform-profiles.md` for each platform's capabilities; refer to `matching-rules.md` for matching logic.

Core approach: identify the task's 1-2 most critical requirement dimensions, match the platform strongest on those dimensions. Don't prioritize a platform because it's "free" or "cheap" — pick the most capable.

### Step 5: Output Research Plan

Based on Step 3's decision, select the corresponding output template.

---

#### Template A: Recon Direct Delivery

Used when Recon results sufficiently answer the user's question.

**Structure compatibility**: If the task has a dedicated output structure (e.g., 6-section: TL;DR / fact table / conflict verification table / action items / pending confirmation / source annotations), **prioritize the task's structure as the main body**; Template A's "Limitations + For deeper investigation" sections serve as closing. Mixing both is reasonable and doesn't count as template deviation.

````markdown
## Research Report: [Topic]

> Based on Quick Recon (Claude Code WebSearch/WebFetch), no external Deep Research platform used.

### Key Findings
[Integrated key findings across facets, structured presentation]

### Data Sources
| Source | URL | Confidence |
|--------|-----|------------|

### Limitations
- [Aspects not covered by Recon]
- [Data timeliness notes]

### For Deeper Investigation
> If you feel any aspect needs more depth, let me know and I can dispatch targeted Deep Research.
````

---

#### Template B: Escalate to Deep Research

Used when external platform deep-diving is needed. **Key difference: the prompt includes Recon's known information, so Deep Research focuses on unknowns.**

````markdown
## Research Plan

### Quick Recon Summary
> [2-3 sentences summarizing known information and core gaps]

### Recommended Platform: [platform name]

**Why this one:** [1-2 sentences focusing on capability-fit rationale]

**Suggested research prompt:**
```
[topic description]

Background (confirmed through preliminary research):
- [Recon high-confidence finding 1]
- [Recon high-confidence finding 2]
- [Recon high-confidence finding 3]

Please focus on these questions (not covered by preliminary research):
1. [knowledge gap 1]
2. [knowledge gap 2]
3. [knowledge gap 3]

[output format / other requirements]
```

**How to use:**
- [Entry URL/path]
- [Estimated duration]

**Caveats:**
- [Known limitations]
- [Parts requiring manual verification]

### Combination Strategy (if applicable)
| Role | Platform | Sub-task | Rationale |
|------|----------|----------|-----------|

> [How platforms coordinate, why combination is needed]

### Alternative Plan
> [When to use alternative, capability differences vs. primary choice]

### Next Steps
> Once you confirm the plan, say "run it" or "submit research" and I'll generate a dispatch page — one-click copy prompt, one-click open platform, all submissions done in 30 seconds.
````

---

## Detailed Reference

- `platform-profiles.md` — Deep Research platform capability profiles
- `matching-rules.md` — Platform matching logic and decision tree
