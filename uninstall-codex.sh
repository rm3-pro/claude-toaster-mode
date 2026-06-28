#!/usr/bin/env bash
# Remove toaster mode from Codex.
set -euo pipefail

CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
HOOKS_JSON="$CODEX_DIR/hooks.json"

if command -v codex >/dev/null 2>&1; then
  codex plugin remove toaster-mode >/dev/null 2>&1 || true
fi

rm -rf "$CODEX_DIR/skills/toaster"
rm -f "$CODEX_DIR/toaster-mode.off" "$CODEX_DIR/.toaster-mode.off" "$CODEX_DIR/hooks/toaster-codex-hook.sh"

if [ -f "$HOOKS_JSON" ]; then
  command -v jq >/dev/null || { echo "error: jq is required to clean direct hooks (brew/apt install jq)"; exit 1; }
  tmp="$(mktemp)"
  jq '
    def strip(ev):
      .hooks[ev] = ((.hooks[ev] // []) | map(select(any(.hooks[]?; ((.command // "") | test("toaster-codex-hook\\.sh|toaster-mode\\.off"))) | not)))
      | if (.hooks[ev] | length) == 0 then del(.hooks[ev]) else . end;
    if .hooks then strip("SessionStart") | strip("UserPromptSubmit") else . end
    | if (.hooks // {}) == {} then del(.hooks) else . end
  ' "$HOOKS_JSON" > "$tmp" && mv "$tmp" "$HOOKS_JSON"
fi

echo "✓ toaster mode removed from Codex. Restart Codex to drop hooks this session."
