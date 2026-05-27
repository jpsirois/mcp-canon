#!/usr/bin/env node
/**
 * Claude Code SessionStart hook: stamp canonical disabledMcpServers
 * onto the current project entry in ~/.claude.json if (and only if)
 * the entry has no disabledMcpServers set yet.
 *
 * Never overwrites an existing per-project list. Always exits 0 so a
 * malformed canonical file can't break Claude Code startup.
 */

const fs = require("fs");
const path = require("path");
const os = require("os");

const CLAUDE_JSON = path.join(os.homedir(), ".claude.json");
const CANONICAL_LINK = path.join(os.homedir(), ".claude", "mcp-canonical.json");

function log(msg) {
  process.stderr.write(`[mcp-canonical-stamp] ${msg}\n`);
}

function safeReadJson(p) {
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch (err) {
    log(`could not read ${p}: ${err.message}`);
    return null;
  }
}

function atomicWriteJson(p, obj) {
  const tmp = `${p}.tmp.${process.pid}`;
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2));
  fs.renameSync(tmp, p);
}

function main() {
  const cwd = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  if (!cwd) {
    log("no project dir resolved; skipping");
    return;
  }

  const canonical = safeReadJson(CANONICAL_LINK);
  if (!canonical || !Array.isArray(canonical.disabledMcpServers)) {
    log("canonical missing or invalid; skipping");
    return;
  }

  const claudeJson = safeReadJson(CLAUDE_JSON);
  if (!claudeJson || typeof claudeJson !== "object") {
    log("~/.claude.json missing or invalid; skipping");
    return;
  }

  claudeJson.projects = claudeJson.projects || {};
  const entry = claudeJson.projects[cwd] || {};
  const current = entry.disabledMcpServers;

  const isEmpty =
    current === undefined ||
    current === null ||
    (Array.isArray(current) && current.length === 0);

  if (!isEmpty) {
    return; // preserve per-project override
  }

  entry.disabledMcpServers = canonical.disabledMcpServers.slice();
  claudeJson.projects[cwd] = entry;

  atomicWriteJson(CLAUDE_JSON, claudeJson);
  log(`stamped ${cwd} with ${canonical.disabledMcpServers.length} disabled servers`);
}

try {
  main();
} catch (err) {
  log(`unexpected error: ${err.message}`);
}
process.exit(0);
