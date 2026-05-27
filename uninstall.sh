#!/usr/bin/env bash
# Reverse of install.sh: remove symlinks and SessionStart hook entry.
# Does NOT touch ~/.claude.json project entries or the canonical file.

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_LINK="$CLAUDE_DIR/hooks/mcp-canonical-stamp.js"
SKILL_LINK="$CLAUDE_DIR/skills/mcp-sync"
CANONICAL_LINK="$CLAUDE_DIR/mcp-canonical.json"

info() { echo "[uninstall] $*"; }

for link in "$HOOK_LINK" "$SKILL_LINK" "$CANONICAL_LINK"; do
  if [[ -L "$link" ]]; then
    rm "$link"
    info "removed symlink: $link"
  fi
done

if [[ -f "$SETTINGS" ]]; then
  tmp="$(mktemp)"
  jq '
    if .hooks.SessionStart then
      .hooks.SessionStart |= map(
        .hooks |= map(select((.command // "") | test("mcp-canonical-stamp\\.js") | not))
      )
      | .hooks.SessionStart |= map(select((.hooks // []) | length > 0))
    else . end
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  info "stripped mcp-canonical-stamp hook from $SETTINGS"
fi

info "done. canonical file and ~/.claude.json project entries left as-is."
