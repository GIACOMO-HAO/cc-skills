# Fact-Check Protocol for High Fact-Density Tasks (v2.2 + v2.4)

> Triggers when task has "hallucination tolerance = extremely low + citation requirement = academic-grade" (policy verification / BOM selection / Chinese primary source research / regulation clause verification / model license verification). Reports delivered directly from Recon **must undergo independent fact-checking** — the main session and SubAgents' own reports cannot self-score.

## Layer 0 — Primary Source Locator Direct Reading (Principle 7 invariant)

For high-risk claims in the ledger **that have locators, read the primary source text directly to arbitrate** — this resolves most factual issues and **doesn't require paid DR / heterogeneous models**. Escalate to Layer 1/2 below only when:
1. Locator is missing or primary source is unreachable (walled-garden / academic full text)
2. Expansion set blind spot scanning is needed
3. Topic involves AI same-faction content requiring cross-faction false-humility dimension judgment

**Heterogeneous reviewers supplement blind spots; they don't replace missing primary source grounding.**

## v2.4 Pre-Check Discipline

1. **Default mode = Deep Research** (reverting "Pro Search normal mode" default) — fact-checking is a rigorous anchor-level task; **rigor > quota savings**; Deep Research quota exists for exactly this type of task; regular Pro Search is only for ad-hoc lightweight verification
2. **Cross-faction mandatory discipline** (triggers only for same-faction content) — When evaluating Anthropic products / LLM benchmarks involving Claude / AI industry narratives, **at least one cross-faction fact-checker must be used** (OpenAI's ChatGPT Deep Research or Google's Gemini Deep Research) for the final **false humility dimension judgment**; **Anthropic-family reviewers (including Sonnet SubAgent / semi-independent Sonnet fact-check) cannot serve as false humility final arbiter** — same-source reviewers are inherently blind to "appears self-deprecating but actually preserves faction advantage" high-dimensional PR-style bias
3. **Cross-validation recommended pairing (v2.4)**: Perplexity DR (Layer 1 primary) + ChatGPT DR (cross-faction calibration, replacing Gemini) + Gemini DR (backup "expansion set blind spot scanning" — known "yi/billion" unit trap + excessive aggregate site acceptance)
4. **Data source 4-tier priority**: benchmark owner / regulation text / company official site (highest) > independent test > vendor self-report > aggregate site / mirror (lowest); large-gap numbers (≥10pp) must have owner direct citation; cross-tier discrepancies are not "conflicts" — both must be annotated

## Fact-Check Two-Layer Flow

### Layer 1 — Perplexity Pro Search Primary Fact-Check (~5 min)

- Perplexity Pro Search recommended as primary — sentence-level citation + industry-leading citation transparency is its strength
- Does not rely on training data, forces web search to pull authoritative sources
- Output: verdict table (✅/⚠️/❌/🟡) + inline citations

### Layer 2 — SubAgent Primary-Source Check for Perplexity Blind Spots (~3 min, critical material only)

- Dispatch a general-purpose SubAgent to read EUR-Lex / vendor official / arxiv primary sources
- Trigger conditions (any one): ① Perplexity single-source conclusion (no multi-source convergence) ② policy-sensitive topic ③ critical material (core scoring items affecting business decisions)
- **Don't re-run everything**, only check 1-2 blind spots Perplexity didn't fully verify

### Conflict Arbitration Order

1. If Layer 1 conflicts with the original report → trust Layer 1 (unless there's strong reason to doubt)
2. If Layer 1 conflicts with Layer 2 → must fall through to primary source direct reading (don't rely on LLM majority vote)
3. If **multiple LLM fact-checkers conflict with each other** → likewise fall through to primary source arbitration

### Empirical Cases

- **EU AI Act verification**: Perplexity Layer 1 was multi-source convergent and high-confidence on most items; a few blind spots were caught by SubAgent Layer 2 primary source reading → two independent fact-checkers agreed on critical material, correcting several over-scored items in the original report.
- **License verification conflict**: The same EU AI Act report was fact-checked by both Gemini + Perplexity, which directly conflicted on DeepSeek-V3 license — Gemini said "all MIT" (wrong), Perplexity said "custom license" (correct). One `curl https://huggingface.co/deepseek-ai/DeepSeek-V3/raw/main/LICENSE-MODEL` resolved it. An LLM's self-assessed "95%+ accuracy" is a typical training-data recall over-confidence trap.
- **Self-bias audit**: A self-bias audit framework self-assessed as "passed" was **unanimously overturned** by cross-faction Deep Research — false-humility bias invisible to self-assessment is a natural blind spot for same-source reviewers. ~65% of SubAgent citation sources came from aggregate sites; benchmark owner direct citations were < 30%.

---

## v3 Mini Assurance — Reviewer Reads Artifact Directly

> Generalization of v2.2 fact-check protocol — v2.2 only triggered for "high fact-density tasks"; v3 extends to all Recon direct delivery reports.
>
> **Core defense**: plausible unsupported success — the main session reads SubAgent summaries instead of raw artifacts, allowing SubAgent micro-hallucinations to propagate to the final report.

**Trigger**: enabled by default for the Recon direct delivery branch (Step 3 selects "deliver directly"); user can skip with `--skip-mini-assurance`; high fact-density tasks continue using v2.2 fact-check (v3 is its generalization, no double-run).

**v2.5 lighter duty**: With Step 2.5's Claim Ledger, Mini Assurance no longer "re-extracts facts" but **audits whether the ledger supports the final report's topic sentences** — can each conclusion sentence trace back to a `confirmed` (not `weak`/`unresolved`) claim in the ledger.

### Flow

After the report draft is generated but before output to user, dispatch a **fresh reviewer SubAgent** (independent context, does not read the draft's "summary / conclusions" sections).

Reviewer input:
- **Claim Ledger** (Step 2.5 output) + Round 1/Round 2 SubAgent artifact .md paths + draft's "key claim list"
- **Task**: for each report topic sentence, assign one of 3 labels:
  - ✅ `supported`: artifact contains original text support (must attach artifact path + key sentence)
  - ⚠️ `unverifiable`: not found in artifact (goes to "needs manual verification" list)
  - ❌ `conflict`: artifacts contradict each other (explain conflict point)
- **Mandatory scope**: all numbers / strong recommendations / causal claims / person/company/time factual assertions
- **Spot check**: 20% random sample of soft judgments
- **Prohibited**: reading draft's "summary / conclusions" sections; changing writing style; filling in claims; outputting rewrite suggestions

**Output**: append a `## Mini Assurance Audit` section at the end of the final report (3-label stats + unverifiable/conflict list + artifact reference paths).

**Cost**: +5-10 min per research run, +10-15% tokens. **Expected effect**: accuracy 70-80% → 85-90%.

**Upgrade path** (evaluate reviewer hit rate after accumulating cases):
- < 5% hit rate → tighten rubric
- 10-30% hit rate → maintain current approach
- > 50% hit rate → upstream Recon quality issue, strengthen SubAgent instructions
