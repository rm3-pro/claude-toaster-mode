#!/usr/bin/env bash
# Optional HUD statusLine installer for Claude Code.
# Shows: toaster state | superpowers | tokens burned | context used/max |
#        compaction | 5h & weekly usage.
# Separate from the toaster installer so it never silently clobbers an
# existing statusLine you may already have.
#
#   curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install-statusline.sh | bash
#
set -euo pipefail

RAW_BASE="${TOASTER_RAW_BASE:-https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT="$CLAUDE_DIR/statusline.sh"
STATUSLINE_CMD="bash \"$SCRIPT\""

command -v jq  >/dev/null || { echo "error: jq is required (brew/apt install jq)"; exit 1; }
command -v curl >/dev/null || { echo "error: curl is required"; exit 1; }

echo "→ installing statusline.sh"
mkdir -p "$CLAUDE_DIR"
curl -fsSL "$RAW_BASE/statusline.sh" -o "$SCRIPT"
chmod +x "$SCRIPT"

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

# Warn before overwriting a different existing statusLine.
existing="$(jq -r '.statusLine.command // empty' "$SETTINGS")"
if [ -n "$existing" ] && ! printf '%s' "$existing" | grep -q 'statusline.sh'; then
  echo "!  existing statusLine found: $existing"
  echo "   overwriting it. (ctrl-c now to keep yours; it is not backed up)"
fi

tmp="$(mktemp)"
jq --arg cmd "$STATUSLINE_CMD" '.statusLine = {"type":"command","command":$cmd}' \
  "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "✓ HUD statusline installed. Open /statusline or restart to see it."
