#!/usr/bin/env node
/**
 * stop-review-gate.mjs — Automated code review gate (Claude Code Stop hook)
 *
 * Before Claude stops, if there are uncommitted code changes, this hook
 * automatically sends them to Codex for review.
 * BLOCK → Claude must fix issues before stopping; ALLOW → proceed.
 *
 * Install: add to settings.json hooks configuration
 * Disable: remove from hooks configuration
 */

import { execSync, execFileSync } from "node:child_process";
import fs from "node:fs";
import process from "node:process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const APPSERVER = path.join(SCRIPT_DIR, "codex-appserver.mjs");
const TIMEOUT_MS = 5 * 60 * 1000;
const MAX_DIFF_CHARS = 50_000;

// ── Hook I/O ─────────────────────────────────────────────────

function readInput() {
  try {
    const raw = fs.readFileSync(0, "utf8").trim();
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

function block(reason) {
  process.stdout.write(JSON.stringify({ decision: "block", reason }) + "\n");
  process.stderr.write(`[stop-review-gate] BLOCKED: ${reason}\n`);
}

function allow(reason) {
  process.stderr.write(`[stop-review-gate] ALLOWED${reason ? `: ${reason}` : ""}\n`);
}

// ── Git ──────────────────────────────────────────────────────

function hasCodeChanges(cwd) {
  try {
    const stat = execSync("git diff --stat HEAD 2>/dev/null", {
      cwd,
      encoding: "utf8",
      timeout: 5000,
    });
    return stat.trim().length > 0;
  } catch {
    return false;
  }
}

function getDiff(cwd) {
  try {
    const diff = execSync("git diff HEAD 2>/dev/null", {
      cwd,
      encoding: "utf8",
      timeout: 10000,
    });
    if (diff.length > MAX_DIFF_CHARS) {
      return (
        diff.slice(0, MAX_DIFF_CHARS) +
        `\n\n[... diff truncated at ${MAX_DIFF_CHARS} chars, ${diff.length} total]`
      );
    }
    return diff;
  } catch {
    return "";
  }
}

// ── Codex review ─────────────────────────────────────────────

function buildPrompt(diff, lastMessage) {
  const claudeBlock = lastMessage
    ? `\n<claude_last_message>\n${lastMessage.slice(0, 3000)}\n</claude_last_message>\n`
    : "";

  return `You are a senior code reviewer running an automated stop-gate check.
Review the code changes below and decide: should Claude stop, or must it fix something first?

<code_changes>
${diff}
</code_changes>
${claudeBlock}
<rules>
- First line MUST be exactly: ALLOW: <reason> or BLOCK: <reason>
- BLOCK only for real problems: bugs, security holes, data loss risk, logic errors, missing critical error handling
- Do NOT block for: style preferences, naming, minor improvements, missing tests (unless a critical path is untested)
- If changes look correct and safe → ALLOW
- If no meaningful code changes → ALLOW
- Focus on: correctness, security, race conditions, rollback risk, edge cases
- Be concise. One strong finding > five weak ones.
</rules>`;
}

function callCodex(prompt, cwd) {
  try {
    const result = execFileSync(
      process.execPath,
      [APPSERVER, "--stdin", "--effort", "high", "--timeout", String(TIMEOUT_MS)],
      {
        cwd,
        encoding: "utf8",
        input: prompt,
        timeout: TIMEOUT_MS + 15000,
        env: process.env,
      }
    );
    return result.trim();
  } catch (err) {
    process.stderr.write(
      `[stop-review-gate] Codex call failed: ${err.message}\n`
    );
    return null;
  }
}

function parseResponse(output) {
  if (!output) {
    return { ok: true, reason: "Codex unavailable, allowing by default" };
  }

  const firstLine = output.split(/\r?\n/, 1)[0].trim();

  if (firstLine.startsWith("ALLOW:")) {
    return { ok: true, reason: firstLine.slice(6).trim() };
  }

  if (firstLine.startsWith("BLOCK:")) {
    const reason = firstLine.slice(6).trim() || output.slice(0, 500);
    return { ok: false, reason };
  }

  return { ok: true, reason: "Ambiguous response, allowing by default" };
}

// ── Main ─────────────────────────────────────────────────────

const input = readInput();
const cwd = input.cwd || process.env.CLAUDE_PROJECT_DIR || process.cwd();

if (!hasCodeChanges(cwd)) {
  allow("No code changes");
  process.exit(0);
}

const diff = getDiff(cwd);
if (!diff) {
  allow("Could not read diff");
  process.exit(0);
}

process.stderr.write("[stop-review-gate] Code changes detected, calling Codex review...\n");

const prompt = buildPrompt(diff, input.last_assistant_message);
const output = callCodex(prompt, cwd);
const result = parseResponse(output);

if (result.ok) {
  allow(result.reason);
} else {
  block(`Codex review found issues: ${result.reason}`);
}
