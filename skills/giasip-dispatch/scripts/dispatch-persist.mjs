#!/usr/bin/env node
/**
 * dispatch-persist.mjs — Unified response logging sink for all dispatch scripts
 *
 * Called by dispatch scripts (codex/gemini/kimi/api) after receiving a complete
 * response. Persists the full first-hand response as an artifact + appends to
 * index.jsonl, ensuring responses are never lost to volatile /tmp or session logs.
 *
 * Usage (called by dispatch scripts, response piped via stdin):
 *   echo "$RESPONSE" | node dispatch-persist.mjs \
 *     --route api-dispatch --model deepseek-v4-pro --status success --latency 6000
 *   prompt   via env  DISPATCH_PROMPT_B64 (base64, avoids escaping)
 *   batch_id via env  DISPATCH_BATCH_ID   (set by skill for multi-dispatch grouping; defaults to solo-*)
 *   mode     via env  DISPATCH_MODE       (single|multi|background; defaults to single)
 *
 * Best-effort: failures never affect the calling script (all exceptions swallowed, exit 0).
 */
import { mkdirSync, appendFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { randomBytes } from "node:crypto";

async function main() {
  // ── args ──
  const a = {};
  for (let i = 2; i < process.argv.length; i += 2) {
    const k = String(process.argv[i] || "").replace(/^--/, "");
    if (k) a[k] = process.argv[i + 1];
  }
  const route = a.route || "unknown";
  const model = a.model || "unknown";
  const status = a.status || "success";
  const latency = Number(a.latency || 0);
  const inputTokens = a["input-tokens"] ? Number(a["input-tokens"]) : null;
  const outputTokens = a["output-tokens"] ? Number(a["output-tokens"]) : null;
  const totalTokens = a["total-tokens"] ? Number(a["total-tokens"]) : null;
  const cost = a.cost ? Number(a.cost) : null;

  // ── env ──
  const mode = process.env.DISPATCH_MODE || "single";
  let prompt = "";
  if (process.env.DISPATCH_PROMPT_B64) {
    try { prompt = Buffer.from(process.env.DISPATCH_PROMPT_B64, "base64").toString("utf8"); } catch { /* ignore */ }
  }

  // ── read full response from stdin ──
  let response = "";
  process.stdin.setEncoding("utf8");
  for await (const chunk of process.stdin) response += chunk;

  // ── ids & paths (concurrency-safe: ms + pid + random, artifact uses wx no-clobber) ──
  const now = new Date();
  const iso = now.toISOString().replace(/\.\d{3}Z$/, "Z");
  const uniq = `${now.getTime()}-${process.pid}-${randomBytes(3).toString("hex")}`;
  const responseId = `${iso.replace(/[-:TZ.]/g, "").slice(0, 14)}-${route}-${model}-${uniq}`;
  const batchId = process.env.DISPATCH_BATCH_ID || `solo-${uniq}`;
  const dateDir = iso.slice(0, 10).replace(/-/g, "/"); // 2026/06/02
  const baseDir = join(homedir(), ".cache", "dispatch");
  const artDir = join(baseDir, "responses", dateDir, batchId);

  // ── write artifact (frontmatter + full PROMPT + RESPONSE) ──
  const fm = [
    "---",
    "schema_version: 1",
    `response_id: ${responseId}`,
    `batch_id: ${batchId}`,
    `mode: ${mode}`,
    `route: ${route}`,
    `model_actual: ${model}`,
    `status: ${status}`,
    `latency_ms: ${latency}`,
    `ts: ${iso}`,
    `prompt_bytes: ${Buffer.byteLength(prompt)}`,
    `response_bytes: ${Buffer.byteLength(response)}`,
    ...(inputTokens != null ? [`input_tokens: ${inputTokens}`] : []),
    ...(outputTokens != null ? [`output_tokens: ${outputTokens}`] : []),
    ...(totalTokens != null ? [`total_tokens: ${totalTokens}`] : []),
    ...(cost != null ? [`cost: ${cost}`] : []),
    "---",
    "## PROMPT", prompt, "", "## RESPONSE", response, "",
  ].join("\n");
  const artPath = join(artDir, `${responseId}.md`);
  try {
    mkdirSync(artDir, { recursive: true });
    try { writeFileSync(artPath, fm, { flag: "wx" }); } catch { writeFileSync(artPath, fm); }
  } catch { /* best effort */ }

  // ── append index.jsonl (consumption entry point; stores preview+meta only, no markdown scan) ──
  try {
    const idx = {
      ts: iso, response_id: responseId, batch_id: batchId, mode, route,
      model_actual: model, status, latency_ms: latency,
      prompt_preview: prompt.slice(0, 120), prompt_bytes: Buffer.byteLength(prompt),
      response_bytes: Buffer.byteLength(response),
      ...(inputTokens != null && { input_tokens: inputTokens }),
      ...(outputTokens != null && { output_tokens: outputTokens }),
      ...(totalTokens != null && { total_tokens: totalTokens }),
      ...(cost != null && { cost }),
      artifact: artPath,
    };
    appendFileSync(join(baseDir, "index.jsonl"), JSON.stringify(idx) + "\n");
  } catch { /* best effort */ }

  process.stdout.write(artPath + "\n");
}

main().catch(() => process.exit(0));
