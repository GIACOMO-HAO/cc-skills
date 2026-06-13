# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] — 2026-06-13

### Changed
- Restructured both skills to standard SKILL.md distribution format (agentskills.io spec)
- Moved supporting docs into `references/` subdirectories
- Slimmed `giasip-research/SKILL.md` from 424 to 276 lines by extracting protocols to references/
- Enhanced SKILL.md frontmatter with `version`, `author`, `license`, `compatibility` fields
- Updated dispatch model roster to current versions (DeepSeek V4-Pro / Qwen3.6 Plus / GLM-5.1 / Kimi K2.6 / Doubao Seed-2.0 Pro / MiniMax M2.7)

### Added
- `skills/giasip-dispatch/scripts/dispatch-persist.mjs` — response logging sink
- `skills/giasip-dispatch/scripts/stop-review-gate.mjs` — Codex stop-hook for code review gating
- `skills/giasip-dispatch/references/model-roster.md` — full model roster with per-model strengths and multi-dispatch lineup recommendations
- `skills/giasip-research/references/fact-check-protocol.md` — extracted fact-check protocol (v2.2+v2.4) + Mini Assurance audit
- `skills/giasip-research/references/subagent-templates.md` — extracted SubAgent instruction templates (Round 1 + Round 2) + unit sanity check
- Complexity routing section in dispatch (auto-selects strategy based on task nature)
- Kimi thinking model discipline (timeout, fast mode, SSE streaming)
- Response logging with `DISPATCH_BATCH_ID` grouping for multi-dispatch runs

## [1.1.0] — 2026-06-08

### Changed
- Adopted `giasip-*` name prefix convention for both skills
- Added `npx skills add` as primary installation method
- Renamed repo to `giasip-skills` for brand consistency
- Restructured as Claude Code plugin with `.claude-plugin/` manifest

## [1.0.0] — 2026-05-04

### Added
- Initial release: `giasip-research` (research orchestrator) and `giasip-dispatch` (multi-model dispatcher)
- 4 dispatch scripts: `api-dispatch.sh`, `codex-appserver.mjs`, `gemini-supervisor.sh`, `kimi-dispatch.sh`
- Research supporting docs: `matching-rules.md`, `platform-profiles.md`
- Chinese locale support (`locales/zh/`)
