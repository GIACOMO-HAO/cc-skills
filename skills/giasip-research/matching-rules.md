# Research Matching Rules

> Core principle: capability fit first — pick the platform best at the task, not the cheapest (within your subscribed platforms).

---

## 1. Matching Flow

```
Receive research task
│
├── 1. Can we handle it in-house?
│   ├── Simple fact lookup → Claude Code does it directly (Firecrawl/WebSearch)
│   └── Needs deep report / walled-garden platform / cross-validation → continue
│
├── 2. Language routing
│   ├── Primarily Chinese → Chinese capability pool
│   ├── Primarily English → English capability pool
│   └── Mixed → combine both pools
│
├── 3. Match strongest platform by task type
│   │  (see Rules A-H below)
│   │
│   └── Key: pick "who is best at this type of task"
│        not "who is cheapest" or "who is free"
│
├── 4. Special requirements weighting
│   ├── Low hallucination → +Claude / +Kimi
│   ├── Academic-grade citations → +Perplexity / +Kimi
│   ├── Mind map → +Metaso AI
│   ├── Ultra-long documents → +MiniMax
│   └── Podcast output → +Gemini
│
└── 5. Usage advisory (noted only, does not affect platform selection)
    ├── ChatGPT Plus 25 uses/month → save for high-value tasks
    ├── Kimi has monthly cap → save for high-value Chinese tasks
    └── Other platforms have no significant limits
```

---

## 2. Capability Pools

### English Capability Pool

| Best Scenario | Top Pick | Key Reason |
|---------------|----------|------------|
| Deep professional research, multimodal analysis, GitHub deep-dive | ChatGPT DR | Deepest reports, richest citations |
| Macro strategic analysis, rapid framework | Gemini DR | Fastest, editable research plan |
| Low hallucination, enterprise data integration | Claude Research | Lowest hallucination rate, MCP internal integration |
| Quick fact-checking, citation tracing | Perplexity | Fastest, highest citation accuracy |
| Twitter sentiment | Grok | Native X data |

### Chinese Capability Pool

| Best Scenario | Top Pick | Key Reason |
|---------------|----------|------------|
| High-quality formal report, academic/policy | Kimi-Researcher | Highest Chinese quality, lowest hallucination |
| Walled-garden platform crawling (CNKI / Xiaohongshu, etc.) | Zhipu AutoGLM | Only platform with browser automation |
| Quick retrieval, mind map | Metaso AI | Good visualization, fast |
| Ultra-long document analysis | MiniMax | 4M token context |
| API integration | Tongyi Qwen DR | API-friendly |

---

## 3. Task Type Matching Rules

### Rule A: High-Stakes Professional Research

> Research reports for clients / leadership / academic publication. Quality is the only criterion.

**English:** ChatGPT Deep Research
- Deepest reports, richest citations — the strongest choice for English deep research
- For extreme complexity: ChatGPT DR + Perplexity cross-validation

**Chinese:** Kimi-Researcher
- Highest Chinese report quality, lowest hallucination, automatic contradiction detection
- When CNKI / WeChat Official Account data is needed: Kimi (analysis) + Zhipu AutoGLM (data acquisition)

**Note:** Numbers and financial data in high-stakes reports must be manually verified; citations must be spot-checked.

### Rule B: Strategic / Industry / Macro Analysis

> Industry trends, market research, competitive landscape

**Top pick:** Gemini Deep Research — highest composite benchmark (DeepResearch Bench 48.88), editable research plan preview, fastest framework output

**When more detail is needed:** Gemini (framework) + ChatGPT DR (deep supplement)

### Rule C: Quick Fact-Checking

> Verify claims, track news, rapid data lookups

**Top pick:** Perplexity — fastest (< 3 min), highest citation accuracy (90.24%), sentence-level tracing

**Chinese fact-checking:** Metaso AI or Zhipu AutoGLM

### Rule D: Enterprise Internal + External Data Integration

> Combining Slack / Jira / CRM data with external information

**Only choice:** Claude Research — connects to internal systems via MCP, lowest hallucination rate

### Rule E: Chinese Walled-Garden Platform Data

> Extracting information from CNKI, Xiaohongshu, WeChat Official Accounts, Zhihu, Taobao

**Top pick:** Zhipu AutoGLM — the only platform with browser automation, can log into restricted platforms

**When deep analysis is also needed:** Zhipu AutoGLM (data acquisition) + Kimi (deep analysis)

### Rule F: Ultra-Long Document Analysis

> Legal contracts, medical records, industrial logs

**Top pick:** MiniMax Agent Pro — 4M token context

### Rule G: Sentiment Analysis

**Twitter/X:** Grok (if unsubscribed, consider a temp subscription or use Perplexity as substitute)
**Chinese social platforms:** Zhipu AutoGLM
**Comprehensive sentiment:** combined approach

### Rule H: Mixed / Other

Match by the most critical requirement dimension — prioritize the core need, then layer on combination strategies.

If the task involves both coding + research → use `/dispatch` for the coding tool + `/research` for the research platform.

---

## 4. Combination Strategies

### English Deep Research Combination

| Role | Platform | Purpose |
|------|----------|---------|
| Primary | ChatGPT DR | Deep report |
| Validation | Perplexity | Citation verification |
| Framework | Gemini | Strategic supplement + Google Docs export |

### Chinese Deep Research Combination

| Role | Platform | Purpose |
|------|----------|---------|
| Primary | Kimi-Researcher | Deep analysis (highest Chinese quality) |
| Data | Zhipu AutoGLM | Walled-garden platform data extraction |
| Quick lookup | Metaso AI | Fast retrieval + mind map visualization |

### Mixed Chinese-English Combination

| Role | Platform | Purpose |
|------|----------|---------|
| English primary | ChatGPT DR | Deep mining of English sources |
| Chinese primary | Kimi or Zhipu AutoGLM | Chinese source coverage |
| Validation | Perplexity | Cross-checking critical claims |

---

## 5. Escalation & Substitution

When the primary platform's results are unsatisfactory:
```
Zhipu AutoGLM not deep enough → escalate to Kimi-Researcher
Gemini lacks detail → escalate to ChatGPT DR
Perplexity lacks depth → escalate to ChatGPT DR or Gemini
Single platform insufficient → enable combination strategy
```

When monthly quota is tight (advisory only):
```
ChatGPT Plus quota tight → non-critical English tasks handled by Gemini
Kimi quota tight → Zhipu AutoGLM + Metaso AI combination as substitute
```

---

## 6. Live Verification Guide

### When to search
1. User mentions a specific research topic → search for latest developments to gauge research difficulty
2. Time-sensitive domain → confirm whether information is outdated
3. Uncertain about a platform's latest features/limits → quick search to confirm

---

## 7. Output Checklist

- [ ] Recommendation is based on capability fit, not cost
- [ ] Provided a ready-to-copy suggested prompt
- [ ] Noted estimated duration
- [ ] Provided combination strategy (if applicable)
- [ ] Gave alternative / escalation plan
- [ ] Reminded about key caveats (hallucination / citation verification)
- [ ] Live verification executed (if needed)
