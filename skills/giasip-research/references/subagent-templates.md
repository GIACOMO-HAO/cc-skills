# SubAgent Instruction Templates

## Round 1 — Breadth Reconnaissance Template

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

## Round 2 — Targeted Gap-Filling Template

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

## High Fact-Density Tasks — Additional Constraints

When the task has "hallucination tolerance = extremely low" AND "citation requirement = academic-grade", Round 2 must include at least 1 "direct primary source reading" task. Primary source types:

- Regulations: EUR-Lex original text (not mirrors like artificialintelligenceact.eu)
- Model licenses: HuggingFace model card LICENSE file via direct curl (distinguish LICENSE / LICENSE-CODE / LICENSE-MODEL)
- Policy texts: gov.cn / xxx.gov.cn primary URLs
- Vendor specs: official spec sheet PDF direct reading

## Unit Sanity Check

All large numbers in the report (FLOPs / GPU-hours / pricing / tokens / parameter count) must be spot-checked for "**number vs. unit correspondence**." Rules:

- Number-unit correspondence must be traceable to the primary source's original text (not a model paraphrase)
- Conversion formulas (e.g., GPU-hours → FLOPs) must be explicitly stated, never assumed
- Numbers ≥ 10²⁰ magnitude get a standalone "pending fact-check" tag
