#!/usr/bin/env bash
# Host-neutral toaster mode uninstaller.
set -euo pipefail

RAW_BASE="${TOASTER_RAW_BASE:-https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main}"
HOST="${TOASTER_HOST:-auto}" # auto | codex | claude | all

command -v curl >/dev/null || { echo "error: curl is required"; exit 1; }

run_remote() {
  curl -fsSL "$RAW_BASE/$1" | bash
}

has_codex=0
has_claude=0
if [ -n "${CODEX_HOME:-}" ] || [ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1; then
  has_codex=1
fi
if [ -n "${CLAUDE_CONFIG_DIR:-}" ] || [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
  has_claude=1
fi

case "$HOST" in
  codex)
    run_remote uninstall-codex.sh
    ;;
  claude)
    run_remote uninstall-claude.sh
    ;;
  all)
    run_remote uninstall-codex.sh
    run_remote uninstall-claude.sh
    ;;
  auto)
    if [ "$has_codex" -eq 1 ]; then run_remote uninstall-codex.sh; fi
    if [ "$has_claude" -eq 1 ]; then run_remote uninstall-claude.sh; fi
    ;;
  *)
    echo "error: TOASTER_HOST must be auto, codex, claude, or all"
    exit 1
    ;;
esac
