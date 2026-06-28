#!/usr/bin/env bash
# Toaster mode installer for Claude Code.
# Installs the /toaster skill + SessionStart/UserPromptSubmit hooks.
#
#   curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install-claude.sh | bash
#
set -euo pipefail

RAW_BASE="${TOASTER_RAW_BASE:-https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
SKILL_DIR="$CLAUDE_DIR/skills/toaster"

HOOK_MSG="TOASTER MODE: answer/action first; fewest words; one recommendation; no preamble/postamble/hedging; safety caveats only. Broad multi-file searches -> Explore subagent; no tool-call narration; do not re-read or re-derive. Do not truncate requested detail: reviews, security notes, graphify/Obsidian/wiki output, walkthroughs, and explicit explanations may expand. After non-trivial code changes: delete sweep for dead code, duplicate logic, unused files/components, and unnecessary complexity. Before final: surface least-confident points and what the user may not realize; investigate material doubts. Secrets never in git: use env vars or ignored .env files. /toaster off to disable."
HOOK_CMD="FLAG=\"\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}/toaster-mode.off\"; test -f \"\$FLAG\" || printf '%s\n' '$HOOK_MSG'"

command -v jq >/dev/null || { echo "error: jq is required (brew/apt install jq)"; exit 1; }
command -v curl >/dev/null || { echo "error: curl is required"; exit 1; }

echo "→ installing Claude /toaster skill"
mkdir -p "$SKILL_DIR"
curl -fsSL "$RAW_BASE/skills/toaster/SKILL.md" -o "$SKILL_DIR/SKILL.md"

echo "→ wiring Claude hooks into $SETTINGS"
mkdir -p "$CLAUDE_DIR"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

tmp="$(mktemp)"
jq --arg cmd "$HOOK_CMD" '
  def toaster_hook: {"hooks":[{"type":"command","command":$cmd,"suppressOutput":true}]};
  def strip_toaster(ev):
    .hooks[ev] = ((.hooks[ev] // [])
      | map(select(any(.hooks[]?; ((.command // "") | test("toaster-mode\\.off"))) | not)));
  def ensure(ev):
    strip_toaster(ev)
    | .hooks[ev] = ((.hooks[ev] // []) + [toaster_hook]);
  .hooks = (.hooks // {}) | ensure("SessionStart") | ensure("UserPromptSubmit")
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "✓ toaster mode installed for Claude Code. ON by default."
echo "  disable: /toaster off   (or: touch \"$CLAUDE_DIR/toaster-mode.off\")"
echo "  enable : /toaster on    (or: rm -f \"$CLAUDE_DIR/toaster-mode.off\")"
echo "  Open /hooks once or restart Claude Code to load the hooks this session."
