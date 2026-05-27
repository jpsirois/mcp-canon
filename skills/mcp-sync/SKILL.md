---
name: mcp-sync
description: Reconcile Claude Code MCP enable/disable state across all project entries in ~/.claude.json. Use when the user toggles an MCP server in /mcp and wants the change to apply everywhere, when they ask to "sync MCP", "promote MCP", "check MCP drift", or when a new project's MCP list looks wrong.
---

# mcp-sync

Manual control plane for the canonical MCP disable list. The companion hook stamps new project entries automatically; this skill is the escape hatch for promoting changes and forcing convergence.

## Commands

Invoke the repo-local script at `~/code/Personal/mcp-canon/bin/mcp-sync` (or wherever the user cloned the repo — resolve via `readlink ~/.claude/hooks/mcp-canonical-stamp.js` then `dirname` twice).

### `mcp-sync status` (default)

Print canonical list and every project entry whose `disabledMcpServers` differs from canonical. Use first when investigating drift.

### `mcp-sync promote`

Read the current project's `disabledMcpServers` from `~/.claude.json` and write it into the canonical file. Use after the user has toggled MCP servers in the `/mcp` UI for one project and wants that state to become the new default.

Errors out if the current project's list is empty — refuse to clobber canonical with nothing.

### `mcp-sync sync`

Overwrite every project entry's `disabledMcpServers` with the canonical list. Also clears `disabledMcpjsonServers`, `enabledMcpjsonServers`, and `mcpServers` per-project overrides. Backs up `~/.claude.json` first.

Use after `promote`, or to force-reset projects that have drifted.

## Typical flow

User says "I just disabled X in /mcp, make it stick everywhere":

1. `mcp-sync promote` — captures current state into canonical
2. `mcp-sync sync` — propagates canonical to all projects
3. Confirm with `mcp-sync status` — should report zero diverging projects

## Safety

- `sync` always backs up `~/.claude.json` to `~/.claude.json.bak.<timestamp>` first.
- `promote` refuses to overwrite canonical with an empty list.
- Hook never overwrites a non-empty per-project list — only stamps null/missing entries.
- All edits are atomic (`mv` over `mktemp` output).

## When NOT to use

- Single one-off toggle for a single project — use the `/mcp` UI directly; the hook will preserve the override on future sessions.
- Inspecting which MCP servers exist — use `/mcp` UI.
