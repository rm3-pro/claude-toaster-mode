#!/usr/bin/env bash
# Remove toaster mode: deletes the skill and strips the hooks from settings.json.
set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"

command -v jq >/dev/null || { echo "error: jq is required"; exit 1; }

rm -rf "$CLAUDE_DIR/skills/toaster"
rm -f  "$CLAUDE_DIR/toaster-mode.off"

if [ -f "$SETTINGS" ]; then
  tmp="$(mktemp)"
  jq '
    def strip(ev):
      .hooks[ev] = ((.hooks[ev] // []) | map(select(any(.hooks[]?; .command | test("toaster-mode.off")) | not)))
      | if (.hooks[ev] | length) == 0 then del(.hooks[ev]) else . end;
    if .hooks then strip("SessionStart") | strip("UserPromptSubmit") else . end
    | if (.hooks // {}) == {} then del(.hooks) else . end
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
fi

echo "✓ toaster mode removed. Restart Claude Code to drop the hooks this session."
