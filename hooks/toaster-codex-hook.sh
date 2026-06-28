#!/usr/bin/env bash
# Toaster mode hook for Codex.
# Emits Codex hook JSON with additional context when toaster mode is enabled.
set -euo pipefail

CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
OFF_FLAG="$CODEX_DIR/toaster-mode.off"
HOOK_EVENT="${TOASTER_HOOK_EVENT:-UserPromptSubmit}"

HOOK_MSG="TOASTER MODE: answer/action first; fewest words; one recommendation; no preamble/postamble/hedging; safety caveats only. Broad multi-file searches -> Explore subagent; no tool-call narration; do not re-read or re-derive. Do not truncate requested detail: reviews, security notes, graphify/Obsidian/wiki output, walkthroughs, and explicit explanations may expand. After non-trivial code changes: delete sweep for dead code, duplicate logic, unused files/components, and unnecessary complexity. Before final: surface least-confident points and what the user may not realize; investigate material doubts. Secrets never in git: use env vars or ignored .env files. /toaster off to disable."

input="$(cat || true)"
prompt="$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null || true)"
prompt_lc="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

cmd=""
case "$prompt_lc" in
  /toaster|/toaster\ status|/toaster\ \?|@toaster|@toaster\ status|@toaster\ \?)
    cmd="status"
    ;;
  /toaster\ on|/toaster\ enable|/toaster\ enabled|@toaster\ on|@toaster\ enable|@toaster\ enabled)
    cmd="on"
    ;;
  /toaster\ off|/toaster\ disable|/toaster\ disabled|@toaster\ off|@toaster\ disable|@toaster\ disabled)
    cmd="off"
    ;;
esac

status_msg=""
case "$cmd" in
  on)
    rm -f "$OFF_FLAG"
    status_msg="TOASTER MODE ON"
    ;;
  off)
    mkdir -p "$CODEX_DIR"
    printf 'off\n' > "$OFF_FLAG"
    status_msg="TOASTER MODE OFF"
    ;;
  status)
    if [ -f "$OFF_FLAG" ]; then
      status_msg="TOASTER MODE: OFF"
    else
      status_msg="TOASTER MODE: ON"
    fi
    ;;
esac

context=""
system_message=""
if [ -n "$status_msg" ]; then
  context="$status_msg"
  system_message="${status_msg/:/}"
fi

if [ ! -f "$OFF_FLAG" ]; then
  context="${context:+$context

}$HOOK_MSG"
  system_message="${system_message:-TOASTER:ON}"
elif [ -z "$context" ]; then
  exit 0
fi

jq -nc \
  --arg systemMessage "$system_message" \
  --arg context "$context" \
  --arg hookEvent "$HOOK_EVENT" \
  '{
    systemMessage: $systemMessage,
    hookSpecificOutput: {
      hookEventName: $hookEvent,
      additionalContext: $context
    }
  }'
