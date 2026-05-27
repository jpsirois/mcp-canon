# mcp-canon

Keep Claude Code's MCP enable/disable state consistent across every project on your machine, without manually toggling each one.

Claude Code stores MCP enable/disable as a **per-project** list inside `~/.claude.json`. Toggling a server in `/mcp` for one project does not affect any other project. `mcp-canon` gives you a single canonical list and:

- a **SessionStart hook** that stamps the canonical list onto any new/empty project entry the first time you open a session there;
- a **`/mcp-sync` skill** with `promote`, `sync`, and `status` modes for manual reconciliation.

## How it works

```
canonical/mcp-canonical.json      ← single source of truth (your list)
        │
        ▼
~/.claude/mcp-canonical.json      ← symlink to source of truth
        │
        ├── read by hook on every SessionStart
        │       └── stamps ~/.claude.json projects[<cwd>].disabledMcpServers
        │           (only if currently null/missing — never overwrites your overrides)
        │
        └── read by `/mcp-sync` skill (manual promote / sync / status)
```

### Source-of-truth location

The canonical file can live in three places. Pick at install time:

| Mode | Path | Backup |
|------|------|--------|
| `--repo` (default) | `<repo>/canonical/mcp-canonical.json` | git |
| `--icloud` | `~/Library/Mobile Documents/com~apple~CloudDocs/dotfiles/.claude-mcp-canonical.json` | iCloud |
| `--path <dir>` | `<dir>/.claude-mcp-canonical.json` | yours |

Either way, `~/.claude/mcp-canonical.json` is a symlink to that location.

## Install

```bash
git clone git@github.com:<you>/mcp-canon.git ~/code/Personal/mcp-canon
cd ~/code/Personal/mcp-canon
./install.sh                # canonical in repo (git-backed)
# OR
./install.sh --icloud       # canonical in iCloud dotfiles
# OR
./install.sh --path ~/my-dotfiles
```

First run copies `canonical/mcp-canonical.example.json` to the resolved canonical path if no canonical file exists yet. Edit that file to taste.

`install.sh` is idempotent — safe to run multiple times. It will not double-register the hook.

### Seeding from a team example

Teams can maintain their own seed canonicals (a starting list for new hires) outside this public repo — for example in a sibling private directory or a separate private repo. `canonical/internal/` and `canonical/*.internal.*` are gitignored, so it is safe to drop a private seed file in there locally without it ever leaking into the public repo:

```bash
cp ../mcp-canon-internal/<team>.example.json "$(readlink ~/.claude/mcp-canonical.json)"
```

## Usage

After install, MCP state syncs automatically on every new project's first session.

Manual operations (run from inside any Claude Code session):

| Command | What it does |
|---------|--------------|
| `/mcp-sync status` | Show canonical list + which projects diverge |
| `/mcp-sync promote` | Copy current project's `disabledMcpServers` → canonical |
| `/mcp-sync sync` | Force every project entry's `disabledMcpServers` = canonical |

Typical flow when you toggle a server in `/mcp`:

1. Toggle the server in Claude Code's `/mcp` UI for the current project.
2. Run `/mcp-sync promote` — pushes that toggled state into canonical.
3. Run `/mcp-sync sync` — propagates canonical to all other projects.

## Hook caveat

Claude Code loads MCP state at process start, before the `SessionStart` hook runs. The hook therefore takes effect on the **next** session of a brand-new project — the very first session of a brand-new project will load with all MCPs enabled. Run `/mcp-sync sync` once after install to retroactively stamp every existing project, then never think about it again.

## Known Claude Code bugs to be aware of

If MCP state behaves unexpectedly, check the upstream issues:

- [anthropics/claude-code#13311](https://github.com/anthropics/claude-code/issues/13311) — `disabledMcpServers` sometimes not enforced at session startup
- [anthropics/claude-code#17299](https://github.com/anthropics/claude-code/issues/17299) — `mcpServers` in project settings replaces instead of merging with global
- [anthropics/claude-code#14490](https://github.com/anthropics/claude-code/issues/14490) — `--strict-mcp-config` does not override `disabledMcpServers`

## Uninstall

```bash
./uninstall.sh
```

Removes symlinks and the `SessionStart` hook entry from `~/.claude/settings.json`. Does not touch your project entries.

## Requirements

- `jq` (used by installer + hook + skill script)
- `node` (used by the hook)
- macOS or Linux

## What this repo does not store

`.gitignore` blocks every file that could contain credentials, oauth tokens, or team-internal data (`.claude.json`, `*credentials*`, `*.token`, `.env*`, `*.local.json`, `canonical/internal/`, `canonical/*.internal.*`). The only data in this repo are:

- the tool's own code (hook, skill, installer)
- a generic **example** canonical list (`canonical/mcp-canonical.example.json`)

Your real canonical lives outside the repo (or as a gitignored copy inside it, if you chose `--repo` mode). Team-specific seed lists also live outside the repo (or in a gitignored path).
