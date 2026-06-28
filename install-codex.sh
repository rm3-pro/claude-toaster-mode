#!/usr/bin/env bash
# Toaster mode installer for Codex.
# Installs the native Codex plugin by default. Set TOASTER_CODEX_INSTALL_MODE=direct
# to use the legacy direct skill + hooks.json fallback.
#
#   curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install-codex.sh | bash
#
set -euo pipefail

RAW_BASE="${TOASTER_RAW_BASE:-https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main}"
MODE="${TOASTER_CODEX_INSTALL_MODE:-plugin}" # plugin | direct
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
HOOKS_JSON="$CODEX_DIR/hooks.json"
HOOK_DIR="$CODEX_DIR/hooks"
HOOK_SCRIPT="$HOOK_DIR/toaster-codex-hook.sh"
SKILL_DIR="$CODEX_DIR/skills/toaster"
SESSION_HOOK_CMD="TOASTER_HOOK_EVENT=SessionStart bash \"$HOOK_SCRIPT\""
PROMPT_HOOK_CMD="TOASTER_HOOK_EVENT=UserPromptSubmit bash \"$HOOK_SCRIPT\""

if [ "$MODE" = "plugin" ] && command -v codex >/dev/null 2>&1; then
  echo "→ installing Codex toaster plugin"
  if (codex plugin marketplace add rm3-pro/claude-toaster-mode --ref main >/dev/null 2>&1 || codex plugin marketplace upgrade toaster-mode >/dev/null 2>&1) &&
    codex plugin add toaster-mode@toaster-mode >/dev/null 2>&1; then
    echo "✓ toaster mode plugin installed for Codex. ON by default."
    echo "  Open /hooks, trust toaster mode hooks, then start a new thread."
    exit 0
  fi
  echo "warning: Codex plugin install failed; falling back to direct hooks." >&2
fi

if [ "$MODE" != "direct" ] && [ "$MODE" != "plugin" ]; then
  echo "error: TOASTER_CODEX_INSTALL_MODE must be plugin or direct"
  exit 1
fi

command -v jq >/dev/null || { echo "error: jq is required for direct install (brew/apt install jq)"; exit 1; }
command -v curl >/dev/null || { echo "error: curl is required for direct install"; exit 1; }

echo "→ installing Codex toaster skill"
mkdir -p "$SKILL_DIR" "$HOOK_DIR"
curl -fsSL "$RAW_BASE/skills/toaster/SKILL.md" -o "$SKILL_DIR/SKILL.md"

echo "→ installing Codex toaster hook"
curl -fsSL "$RAW_BASE/hooks/toaster-codex-hook.sh" -o "$HOOK_SCRIPT"
chmod +x "$HOOK_SCRIPT"

echo "→ wiring Codex hooks into $HOOKS_JSON"
[ -f "$HOOKS_JSON" ] || echo '{}' > "$HOOKS_JSON"

tmp="$(mktemp)"
jq --arg session_cmd "$SESSION_HOOK_CMD" --arg prompt_cmd "$PROMPT_HOOK_CMD" '
  def toaster_hook(cmd): {"hooks":[{"type":"command","command":cmd,"timeout":5,"statusMessage":"Loading toaster mode..."}]};
  def strip_toaster(ev):
    .hooks[ev] = ((.hooks[ev] // [])
      | map(select(any(.hooks[]?; ((.command // "") | test("toaster-codex-hook\\.sh|toaster-mode\\.off"))) | not)));
  def ensure(ev; matcher; cmd):
    strip_toaster(ev)
    | .hooks[ev] = ((.hooks[ev] // []) + [if matcher == "" then toaster_hook(cmd) else toaster_hook(cmd) + {"matcher": matcher} end]);
  .hooks = (.hooks // {})
  | ensure("SessionStart"; "startup|resume|clear|compact"; $session_cmd)
  | ensure("UserPromptSubmit"; ""; $prompt_cmd)
' "$HOOKS_JSON" > "$tmp" && mv "$tmp" "$HOOKS_JSON"

echo "✓ toaster mode installed for Codex. ON by default."
echo "  disable: /toaster off   (or: touch \"$CODEX_DIR/toaster-mode.off\")"
echo "  enable : /toaster on    (or: rm -f \"$CODEX_DIR/toaster-mode.off\")"
echo "  Open /hooks once or restart Codex to trust/load the hooks this session."
