#!/usr/bin/env bash
# Toaster mode installer for Claude Code.
# Installs the /toaster skill + SessionStart/UserPromptSubmit hooks so terse
# "answer/action only" replies are the default on every machine.
#
#   curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install.sh | bash
#
set -euo pipefail

RAW_BASE="${TOASTER_RAW_BASE:-https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
SKILL_DIR="$CLAUDE_DIR/skills/toaster"

HOOK_CMD="test -f ~/.claude/toaster-mode.off || echo 'TOASTER MODE: answer/action first; fewest words; one recommendation; no preamble/postamble/hedging; safety caveats only. Broad multi-file searches -> Explore subagent (single known-file lookups stay inline); keep file dumps out of main context. No tool-call narration. Do not re-read or re-derive. /toaster off to disable.'"

command -v jq  >/dev/null || { echo "error: jq is required (brew/apt install jq)"; exit 1; }
command -v curl >/dev/null || { echo "error: curl is required"; exit 1; }

echo "→ installing /toaster skill"
mkdir -p "$SKILL_DIR"
curl -fsSL "$RAW_BASE/skills/toaster/SKILL.md" -o "$SKILL_DIR/SKILL.md"

echo "→ wiring hooks into $SETTINGS"
mkdir -p "$CLAUDE_DIR"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

tmp="$(mktemp)"
jq --arg cmd "$HOOK_CMD" '
  def ensure(ev):
    .hooks[ev] = ((.hooks[ev] // [])
      | if any(.[]?.hooks[]?; .command == $cmd) then .
        else . + [{"hooks":[{"type":"command","command":$cmd,"suppressOutput":true}]}] end);
  .hooks = (.hooks // {}) | ensure("SessionStart") | ensure("UserPromptSubmit")
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "✓ toaster mode installed. ON by default."
echo "  disable: /toaster off   (or: touch ~/.claude/toaster-mode.off)"
echo "  enable : /toaster on    (or: rm -f ~/.claude/toaster-mode.off)"
echo "  Open /hooks once or restart Claude Code to load the hooks this session."
