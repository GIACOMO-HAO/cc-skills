#!/usr/bin/env node
/**
 * codex-appserver.mjs — Codex App Server 直连调用
 *
 * 替换 `codex exec --ephemeral`，通过 App Server JSON-RPC 协议直连。
 * 消除 CLI 冷启动开销，结构化错误处理，支持优雅超时。
 *
 * Usage:
 *   node codex-appserver.mjs [options] "prompt"
 *   echo "prompt" | node codex-appserver.mjs --stdin [options]
 *
 * Options:
 *   --model MODEL       模型 (默认: config.toml 配置)
 *   --effort EFFORT      推理强度: none|minimal|low|medium|high|xhigh
 *   --sandbox SANDBOX    沙箱: read-only|full (默认: read-only)
 *   --timeout MS         超时 (默认: 600000)
 *   --stdin              从 stdin 读取 prompt
 *   --cwd DIR            工作目录 (默认: cwd)
 *
 * Exit: 0 = success (stdout), 1 = error (stderr)
 *
 * Protocol reference: openai/codex-plugin-cc app-server.mjs + codex.mjs
 */

import { spawn } from "node:child_process";
import { symlinkSync, unlinkSync, lstatSync, mkdirSync, appendFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { randomBytes } from "node:crypto";
import readline from "node:readline";
import process from "node:process";

// ── Logging (JSONL) — same format as gemini-supervisor.sh ──
const LOG_DIR = join(homedir(), ".cache", "dispatch");
const LOG_FILE = join(LOG_DIR, "codex.log");
try { mkdirSync(LOG_DIR, { recursive: true }); } catch { /* best effort */ }

function logEvent({ model, attempt = 1, status, latencyMs, extra = null }) {
  const ts = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const line = JSON.stringify({
    ts,
    model: String(model),
    attempt: Number(attempt),
    status: String(status),
    latency_ms: Number(latencyMs),
    extra,
  });
  try { appendFileSync(LOG_FILE, line + "\n"); } catch { /* never block on logging */ }
}

// ── Arg parsing ──────────────────────────────────────────────

const args = {
  model: null,
  effort: null,
  sandbox: "read-only",
  timeout: 600_000,
  useStdin: false,
  cwd: process.cwd(),
  prompt: "",
};

const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  switch (argv[i]) {
    case "--model":
    case "-m":
      args.model = argv[++i];
      break;
    case "--effort":
    case "-e":
      args.effort = argv[++i];
      break;
    case "--sandbox":
    case "-s":
      args.sandbox = argv[++i];
      break;
    case "--timeout":
    case "-t":
      args.timeout = parseInt(argv[++i], 10);
      break;
    case "--stdin":
      args.useStdin = true;
      break;
    case "--cwd":
      args.cwd = argv[++i];
      break;
    case "--help":
    case "-h":
      process.stderr.write(
        [
          "Usage: node codex-appserver.mjs [options] \"prompt\"",
          "",
          "Options:",
          "  --model MODEL    模型 (默认: config.toml)",
          "  --effort EFFORT  推理强度: none|minimal|low|medium|high|xhigh",
          "  --sandbox MODE   read-only|full (默认: read-only)",
          "  --timeout MS     超时毫秒 (默认: 600000)",
          "  --stdin          从 stdin 读取 prompt",
          "  --cwd DIR        工作目录",
          "",
        ].join("\n")
      );
      process.exit(0);
      break;
    default:
      if (!argv[i].startsWith("-")) args.prompt = argv[i];
      break;
  }
}

if (args.useStdin) {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  args.prompt = Buffer.concat(chunks).toString("utf8").trim();
}

if (!args.prompt) {
  process.stderr.write(
    '[codex-appserver] 错误: 缺少 prompt。用法: node codex-appserver.mjs "prompt"\n'
  );
  process.exit(1);
}

// ── Validate sandbox ────────────────────────────────────────
const VALID_SANDBOXES = ["read-only", "full", "workspace-write", "danger-full-access"];
const SANDBOX_PROTOCOL_MAP = { "full": "workspace-write" };
if (!VALID_SANDBOXES.includes(args.sandbox)) {
  process.stderr.write(
    `[codex-appserver] 错误: 无效的 --sandbox 值 "${args.sandbox}"。` +
    `合法值: ${VALID_SANDBOXES.join(", ")}\n`
  );
  process.exit(1);
}

// ── Non-ASCII cwd workaround ────────────────────────────────
// Codex app-server 无法处理包含中文等非 ASCII 字符的工作目录。
// 检测后创建临时 symlink 指向真实路径，退出时清理。
const NON_ASCII_RE = /[^\x00-\x7F]/;
let cwdSymlink = null;

// Fix: resolve to absolute path first, so symlink target is never relative
args.cwd = resolve(args.cwd);

if (NON_ASCII_RE.test(args.cwd)) {
  const safeName = `codex-dispatch-${randomBytes(4).toString("hex")}`;
  cwdSymlink = join("/tmp", safeName);
  try {
    symlinkSync(args.cwd, cwdSymlink);
    log(`cwd 含非 ASCII 字符，创建 symlink: ${cwdSymlink} → ${args.cwd}`);
    args.cwd = cwdSymlink;
  } catch (e) {
    // Fix #4: fail-fast instead of fallback to known-crashing path
    log(`错误: 无法创建 symlink (${e.message})，cwd 含非 ASCII 字符，Codex 无法处理`);
    process.exit(1);
  }
}

function cleanupSymlink() {
  if (!cwdSymlink) return;
  // Fix: use lstatSync instead of existsSync — lstat checks the symlink itself,
  // not the target. existsSync follows the link and misses dangling symlinks.
  try { lstatSync(cwdSymlink); unlinkSync(cwdSymlink); } catch { /* already gone */ }
}

// Fix #5: signal handlers do graceful child shutdown before exit
process.on("SIGINT", async () => {
  cleanupSymlink();
  try { await client.close(); } catch { /* best effort */ }
  process.exit(130);
});
process.on("SIGTERM", async () => {
  cleanupSymlink();
  try { await client.close(); } catch { /* best effort */ }
  process.exit(143);
});

// ── Minimal JSON-RPC client ──────────────────────────────────

class CodexClient {
  constructor() {
    this.pending = new Map();
    this.nextId = 1;
    this.onNotification = null;
    this.proc = null;
    this.stderrBuf = "";
    this._resolveExit = null;
    this._exitPromise = new Promise((r) => {
      this._resolveExit = r;
    });
    this._exited = false;
  }

  start(cwd) {
    this.proc = spawn("codex", ["app-server"], {
      cwd,
      stdio: ["pipe", "pipe", "pipe"],
      env: process.env,
    });

    this.proc.stdout.setEncoding("utf8");
    this.proc.stderr.setEncoding("utf8");
    this.proc.stderr.on("data", (d) => {
      this.stderrBuf += d;
    });

    const rl = readline.createInterface({ input: this.proc.stdout });
    rl.on("line", (line) => this._onLine(line));

    this.proc.on("error", (err) => this._onExit(err));
    this.proc.on("exit", (code, signal) => {
      this._onExit(
        code === 0
          ? null
          : new Error(
              `codex app-server exited (${signal ? `signal ${signal}` : `code ${code}`})`
            )
      );
    });
  }

  request(method, params) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject, method });
      this._write({ jsonrpc: "2.0", id, method, params });
    });
  }

  notify(method, params = {}) {
    this._write({ jsonrpc: "2.0", method, params });
  }

  async close() {
    if (this.proc && !this.proc.killed) {
      this.proc.stdin.end();
      const kill = setTimeout(() => {
        if (this.proc && !this.proc.killed && this.proc.exitCode === null) {
          this.proc.kill("SIGTERM");
        }
      }, 500);
      kill.unref?.();
    }
    await this._exitPromise;
  }

  get cleanStderr() {
    return this.stderrBuf
      .split(/\r?\n/)
      .map((l) => l.trimEnd())
      .filter((l) => l && !l.startsWith("WARNING: proceeding"))
      .join("\n");
  }

  _write(obj) {
    this.proc?.stdin?.write(JSON.stringify(obj) + "\n");
  }

  _onLine(line) {
    if (!line.trim()) return;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      return;
    }

    // Server-initiated request (unsupported)
    if (msg.id !== undefined && msg.method) {
      this._write({
        jsonrpc: "2.0",
        id: msg.id,
        error: { code: -32601, message: `Unsupported: ${msg.method}` },
      });
      return;
    }

    // Response to our request
    if (msg.id !== undefined) {
      const p = this.pending.get(msg.id);
      if (!p) return;
      this.pending.delete(msg.id);
      if (msg.error) {
        const err = new Error(msg.error.message || `${p.method} failed`);
        err.rpcCode = msg.error.code;
        p.reject(err);
      } else {
        p.resolve(msg.result ?? {});
      }
      return;
    }

    // Notification (no id)
    if (msg.method && this.onNotification) {
      this.onNotification(msg);
    }
  }

  _onExit(err) {
    if (this._exited) return;
    this._exited = true;
    for (const p of this.pending.values()) {
      p.reject(err || new Error("codex app-server connection closed"));
    }
    this.pending.clear();
    this._resolveExit();
  }
}

// ── Turn capture (simplified from codex-plugin-cc captureTurn) ──

function captureTurn(client, threadId, startFn, timeout) {
  return new Promise(async (resolveOuter, rejectOuter) => {
    let lastMessage = "";
    let completed = false;
    let inferTimer = null;

    const timer = setTimeout(() => {
      if (!completed) {
        completed = true;
        rejectOuter(new Error(`Codex 响应超时 (${timeout / 1000}s)`));
      }
    }, timeout);

    function finish(text) {
      if (completed) return;
      completed = true;
      clearTimeout(timer);
      if (inferTimer) clearTimeout(inferTimer);
      resolveOuter(text);
    }

    function scheduleInferred() {
      if (inferTimer) clearTimeout(inferTimer);
      inferTimer = setTimeout(() => {
        finish(lastMessage);
      }, 300);
      inferTimer.unref?.();
    }

    // Set up notification handler BEFORE sending request
    client.onNotification = (msg) => {
      const p = msg.params;
      switch (msg.method) {
        case "turn/started":
          log(`Turn started`);
          break;

        case "item/started": {
          const item = p?.item;
          if (!item) break;
          if (item.type === "commandExecution") {
            log(`Running: ${shorten(item.command)}`);
          } else if (item.type === "enteredReviewMode") {
            log(`Reviewing...`);
          }
          break;
        }

        case "item/completed": {
          const item = p?.item;
          if (!item) break;
          if (item.type === "agentMessage" && item.text) {
            lastMessage = item.text;
            if (item.phase === "final_answer") {
              log(`Final answer received`);
              scheduleInferred();
            }
          } else if (item.type === "exitedReviewMode" && item.review) {
            lastMessage = item.review;
          } else if (item.type === "commandExecution") {
            log(`Command ${item.status} (exit ${item.exitCode ?? "?"})`);
          }
          break;
        }

        case "turn/completed":
          log(`Turn completed`);
          finish(lastMessage);
          break;

        case "error":
          if (!completed) {
            completed = true;
            clearTimeout(timer);
            if (inferTimer) clearTimeout(inferTimer);
            rejectOuter(new Error(p?.error?.message || "Codex error"));
          }
          break;
      }
    };

    try {
      const res = await startFn();
      // Handle immediate completion (rare)
      if (res.turn?.status && res.turn.status !== "inProgress") {
        finish(lastMessage);
      }
    } catch (err) {
      if (!completed) {
        completed = true;
        clearTimeout(timer);
        if (inferTimer) clearTimeout(inferTimer);
        rejectOuter(err);
      }
    }
  });
}

// ── Helpers ──────────────────────────────────────────────────

function log(msg) {
  process.stderr.write(`[codex-appserver] ${msg}\n`);
}

function shorten(text, limit = 72) {
  const s = String(text ?? "")
    .trim()
    .replace(/\s+/g, " ");
  return s.length <= limit ? s : s.slice(0, limit - 3) + "...";
}

// ── Main ─────────────────────────────────────────────────────

const client = new CodexClient();
client.start(args.cwd);

const _logModel = `codex-${args.model || "default"}`;
const _logExtra = { effort: args.effort, sandbox: args.sandbox };
const _startedAt = Date.now();

try {
  // 1. Initialize handshake
  await client.request("initialize", {
    clientInfo: {
      title: "dispatch",
      name: "Claude Code Dispatch",
      version: "1.0.0",
    },
    capabilities: {
      experimentalApi: false,
      optOutNotificationMethods: [
        "item/agentMessage/delta",
        "item/reasoning/summaryTextDelta",
        "item/reasoning/summaryPartAdded",
        "item/reasoning/textDelta",
      ],
    },
  });
  client.notify("initialized");

  // 2. Start ephemeral thread
  const threadRes = await client.request("thread/start", {
    cwd: args.cwd,
    model: args.model,
    approvalPolicy: "never",
    sandbox: SANDBOX_PROTOCOL_MAP[args.sandbox] || args.sandbox,
    serviceName: "claude_code_dispatch",
    ephemeral: true,
    experimentalRawEvents: false,
  });
  const threadId = threadRes.thread.id;
  log(`Thread ready (${threadId})`);

  // 3. Execute turn and capture result
  const output = await captureTurn(
    client,
    threadId,
    () =>
      client.request("turn/start", {
        threadId,
        input: [{ type: "text", text: args.prompt, text_elements: [] }],
        model: args.model,
        effort: args.effort,
        outputSchema: null,
      }),
    args.timeout
  );

  // 4. Output result
  if (output) {
    logEvent({
      model: _logModel,
      status: "success",
      latencyMs: Date.now() - _startedAt,
      extra: _logExtra,
    });
    process.stdout.write(output + "\n");
  } else {
    throw new Error("Codex 未返回内容");
  }
} catch (err) {
  log(`错误: ${err.message}`);
  const stderr = client.cleanStderr;
  if (stderr) log(`Codex stderr:\n${stderr}`);
  const _msg = err.message || "";
  const _status = /超时|timeout/i.test(_msg)
    ? "timeout"
    : /未返回内容/.test(_msg)
      ? "empty_response"
      : /connection closed|app-server exited/i.test(_msg)
        ? "appserver_exit"
        : "error";
  logEvent({
    model: _logModel,
    status: _status,
    latencyMs: Date.now() - _startedAt,
    extra: { ..._logExtra, error: _msg.slice(0, 200) },
  });
  process.exitCode = 1;
} finally {
  // Fix #1: always runs — process.exitCode lets finally execute before exit,
  // unlike process.exit(1) which skips finally blocks.
  await client.close();
  cleanupSymlink();
}
