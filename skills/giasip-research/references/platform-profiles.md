# Deep Research Platform Profiles

> Reference for the `/research` skill to look up each Deep Research platform's capabilities.
>
> **Matching principle: pick the strongest capability, not the lowest cost.**

---

## Platform Availability (fill in based on your subscriptions)

> The matching logic uses this table to determine which platforms are available. Fill in based on the platforms you actually subscribe to — unsubscribed platforms are marked unavailable and will be auto-skipped or replaced during matching.

| Platform | Available | Monthly Usage Note |
|----------|-----------|-------------------|
| Claude Research | ✅ / ❌ | Depends on subscription tier |
| ChatGPT DR | ✅ / ❌ | Plus Deep Research has a monthly cap |
| Gemini DR | ✅ / ❌ | Depends on subscription tier |
| Perplexity | ✅ / ❌ | Pro tier is generous |
| Kimi-Researcher | ✅ / ❌ | Paid tier has a monthly cap |
| Grok | ✅ / ❌ | Twitter/X sentiment analysis only |
| Zhipu AutoGLM / Metaso AI | ✅ / ❌ | Free tier typically unlimited |
| MiniMax / Tongyi Qwen | ✅ / ❌ | Pay-per-use or API billing |

---

## International Platforms

### ChatGPT Deep Research (OpenAI)
- Engine: o3 / o4-mini (RL fine-tuned)
- Speed: medium-slow (5-30 min) | Report: 23+ pages
- **Strongest at**: multimodal (PDF + image + text), deepest reports, richest citations
- **Best for**: high-stakes English professional research, investment analysis, academic reviews, competitive intelligence, deep GitHub mining
- **Weak at**: Chinese coverage, speed

### Gemini Deep Research (Google)
- Engine: Gemini 2.5 Pro (MoE)
- Speed: fast (1-5 min) | Report: 15-22 pages
- **Strongest at**: editable research plan preview, Google ecosystem integration, podcast output, most effective citations (111+)
- **Best for**: strategic / industry / market macro analysis, rapid framework generation
- **Weak at**: no multimodal analysis, less detailed than ChatGPT

### Claude Research (Anthropic)
- Engine: Claude Sonnet + Extended Thinking
- Speed: slow (15-30+ min) | Report: ~5 pages (concise style)
- **Strongest at**: lowest hallucination rate (~24%), only platform with internal data integration (MCP), parallel search
- **Best for**: enterprise internal + external data integration, technical / code research, low-hallucination decision briefs
- **Weak at**: few citations (~20), short reports

### Perplexity Deep Research
- Engine: DeepSeek-R1 (optimized)
- Speed: fastest (< 3 min) | Report: 7-12 pages
- **Strongest at**: fastest, highest citation accuracy (90.24%), sentence-level citation tracing
- **Best for**: quick fact-checking, real-time news tracking, high citation transparency requirements
- **Weak at**: shallowest depth, inconsistent report quality

### Grok Deep Search (xAI)
- Engine: Grok 3
- **Strongest at**: native Twitter/X integration, real-time social sentiment
- **Best for**: Twitter topic tracking (single use case)
- **Weak at**: high hallucination rate, very few citations

---

## Chinese Platforms

### Zhipu AutoGLM Rumination
- Engine: GLM-Z1-Rumination (32B MoE)
- Speed: slow (15-30+ min) | Report: ~10,000 Chinese characters
- **Strongest at**: browser automation (can log into CNKI / Xiaohongshu / WeChat Official Accounts / Zhihu / Taobao), widest Chinese coverage
- **Best for**: extracting data from Chinese walled-garden platforms, tasks requiring authenticated access
- **Weak at**: report depth vs ChatGPT/Kimi, occupies local browser, weak on English academic

### Kimi-Researcher (Moonshot)
- Engine: end-to-end agentic RL specialized model
- Speed: slowest (up to 1 hour) | Report: ~7,500 characters | HLE: 26.9%
- **Strongest at**: highest Chinese report quality, ultra-low hallucination, automatic contradiction detection, strict information screening
- **Best for**: academic literature reviews, policy/regulation comparison, high-credibility formal Chinese reports
- **Weak at**: slowest speed, monthly quota

### MiniMax Agent Pro
- Engine: MiniMax-M1/M2.1 (230B MoE)
- Speed: fast (100+ tokens/sec)
- **Strongest at**: 4M token ultra-long context, extremely low cost
- **Best for**: ultra-long document analysis (legal contracts / medical records / industrial logs)
- **Weak at**: no standalone Deep Research interface

### Metaso AI Deep Research
- Engine: DeepSeek-R1 + proprietary model
- Speed: medium
- **Strongest at**: mind map visualization, good privacy protection
- **Best for**: Chinese quick retrieval, mind-map-assisted analysis
- **Weak at**: newer product, limited ecosystem integration

### Tongyi Qwen Deep Research
- Engine: Qwen
- Speed: medium
- **Strongest at**: solid Chinese capability, API-integration friendly
- **Best for**: API developers, Chinese research supplement
- **Weak at**: relatively basic features

---

## Unique Capability Quick Reference

| Unique Capability | Only / Best Platform |
|-------------------|---------------------|
| Multimodal research (PDF + image + text) | ChatGPT |
| Editable research plan preview | Gemini |
| Enterprise internal data integration (MCP) | Claude |
| Highest citation accuracy + sentence-level tracing | Perplexity |
| Twitter/X real-time sentiment | Grok |
| Browser automation (CNKI / Xiaohongshu, etc.) | Zhipu AutoGLM |
| Chinese report quality + contradiction detection | Kimi |
| 4M token ultra-long context | MiniMax |
| Mind map visualization | Metaso AI |
| Google ecosystem + podcast output | Gemini |

---

## Capability Scoring Matrix

| Platform | Report Depth | Citation Reliability | Speed | Hallucination Risk | Chinese Capability |
|----------|-------------|---------------------|-------|--------------------|--------------------|
| ChatGPT DR | ★★★★★ | ★★★ | ★★ | Medium | ★★ |
| Gemini DR | ★★★★ | ★★★★ | ★★★★ | Medium | ★★ |
| Claude Research | ★★★★ | ★★★★ | ★★★ | Lowest | ★★★ |
| Perplexity | ★★★ | ★★★★★ | ★★★★★ | Low | ★★ |
| Grok | ★★ | ★ | ★★★★ | High | ★ |
| Zhipu AutoGLM | ★★★ | ★★★ | ★★ | Medium | ★★★★★ |
| Kimi | ★★★★★ | ★★★★★ | ★ | Lowest | ★★★★★ |
| MiniMax | ★★★ | ★★★ | ★★★★ | Medium | ★★★ |
| Metaso AI | ★★★ | ★★★ | ★★★ | Medium | ★★★★★ |
| Tongyi Qwen DR | ★★★ | ★★★ | ★★★ | Medium | ★★★★ |
