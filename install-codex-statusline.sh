#!/usr/bin/env bash
# Optional native Codex TUI footer installer.
# Codex does not run Claude Code's statusLine shell contract; it has its own
# [tui].status_line setting in ~/.codex/config.toml.
#
#   curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install-codex-statusline.sh | bash
#
set -euo pipefail

CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG="$CODEX_DIR/config.toml"
STATUS_LINE='["model-with-reasoning", "context-remaining", "five-hour-limit", "weekly-limit", "used-tokens", "git-branch", "task-progress", "current-dir"]'

mkdir -p "$CODEX_DIR"
[ -f "$CONFIG" ] || : > "$CONFIG"

backup="$(mktemp "$CONFIG.toaster-statusline.bak.XXXXXX")"
cp "$CONFIG" "$backup"

tmp="$(mktemp)"
awk -v line="status_line = $STATUS_LINE" '
  /^\[tui\][[:space:]]*$/ {
    if (in_tui && !wrote) {
      print line
      wrote = 1
    }
    saw_tui = 1
    in_tui = 1
    print
    next
  }

  /^\[[^]]+\][[:space:]]*$/ {
    if (in_tui && !wrote) {
      print line
      wrote = 1
    }
    in_tui = 0
    print
    next
  }

  in_tui && /^[[:space:]]*status_line[[:space:]]*=/ {
    if (!wrote) {
      print line
      wrote = 1
    }
    next
  }

  { print }

  END {
    if (in_tui && !wrote) {
      print line
    } else if (!saw_tui) {
      print ""
      print "[tui]"
      print line
    }
  }
' "$CONFIG" > "$tmp"

mv "$tmp" "$CONFIG"

echo "✓ Codex statusline configured in $CONFIG"
echo "  backup: $backup"
echo "  fields: model/reasoning, context, 5h+weekly limits, tokens, git, task progress, cwd"
echo "  restart Codex, or use /statusline inside Codex to adjust interactively."
