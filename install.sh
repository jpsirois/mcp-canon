#!/usr/bin/env bash
# Install mcp-canon hook + skill + canonical symlink.
#
# Usage:
#   ./install.sh              # canonical stored in this repo (git-backed)
#   ./install.sh --icloud     # canonical stored in iCloud dotfiles
#   ./install.sh --path DIR   # canonical stored in DIR/.claude-mcp-canonical.json
#
# Idempotent. Re-running upgrades symlinks but never duplicates the hook.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_SRC="$REPO_DIR/hooks/mcp-canonical-stamp.js"
HOOK_LINK="$CLAUDE_DIR/hooks/mcp-canonical-stamp.js"
SKILL_SRC="$REPO_DIR/skills/mcp-sync"
SKILL_LINK="$CLAUDE_DIR/skills/mcp-sync"
CANONICAL_LINK="$CLAUDE_DIR/mcp-canonical.json"
EXAMPLE="$REPO_DIR/canonical/mcp-canonical.example.json"

ICLOUD_DEFAULT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/dotfiles/.claude-mcp-canonical.json"

mode="repo"
custom_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --icloud) mode="icloud"; shift ;;
    --path)   mode="path"; custom_path="${2:-}"; shift 2 ;;
    --repo)   mode="repo"; shift ;;
    -h|--help)
      sed -n '2,9p' "$0"
      exit 0
      ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

die() { echo "[install] $*" >&2; exit 1; }
info() { echo "[install] $*"; }

command -v jq   >/dev/null || die "jq is required"
command -v node >/dev/null || die "node is required"

mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/skills"

# --- resolve canonical destination ---
case "$mode" in
  repo)
    canonical_dest="$REPO_DIR/canonical/mcp-canonical.json"
    ;;
  icloud)
    icloud_dir="$(dirname "$ICLOUD_DEFAULT")"
    [[ -d "$icloud_dir" ]] || die "iCloud dotfiles dir not found: $icloud_dir"
    canonical_dest="$ICLOUD_DEFAULT"
    ;;
  path)
    [[ -n "$custom_path" ]] || die "--path requires a directory argument"
    mkdir -p "$custom_path"
    canonical_dest="$custom_path/.claude-mcp-canonical.json"
    ;;
esac

# --- create canonical if missing ---
if [[ ! -f "$canonical_dest" ]]; then
  cp "$EXAMPLE" "$canonical_dest"
  info "created canonical: $canonical_dest"
else
  info "canonical exists: $canonical_dest (left untouched)"
fi

# --- symlink ~/.claude/mcp-canonical.json -> canonical_dest ---
ln -sfn "$canonical_dest" "$CANONICAL_LINK"
info "symlink $CANONICAL_LINK -> $canonical_dest"

# --- symlink hook + skill into ~/.claude ---
chmod +x "$HOOK_SRC"
ln -sfn "$HOOK_SRC" "$HOOK_LINK"
info "symlink $HOOK_LINK -> $HOOK_SRC"

ln -sfn "$SKILL_SRC" "$SKILL_LINK"
info "symlink $SKILL_LINK -> $SKILL_SRC"

# --- register SessionStart hook in settings.json (idempotent) ---
if [[ ! -f "$SETTINGS" ]]; then
  echo "{}" > "$SETTINGS"
fi

node_bin="$(command -v node)"
hook_cmd="\"$node_bin\" \"$HOOK_LINK\""

tmp="$(mktemp)"
jq --arg cmd "$hook_cmd" '
  .hooks = (.hooks // {}) |
  .hooks.SessionStart = (.hooks.SessionStart // []) |
  if any(.hooks.SessionStart[]?.hooks[]?; .command == $cmd) then
    .
  else
    .hooks.SessionStart += [{
      "hooks": [{
        "type": "command",
        "command": $cmd,
        "timeout": 5,
        "statusMessage": "Stamping canonical MCP disable list..."
      }]
    }]
  end
' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"
info "registered SessionStart hook in $SETTINGS"

info "done. run 'bin/mcp-sync sync' to retroactively stamp existing projects."
