# claude-toaster-mode

Make **terse, answer/action-only** replies the permanent default for [Claude Code](https://claude.com/claude-code) — on every machine, every chat.

"Toaster mode" = no preamble, no postamble, no hedging, one recommendation instead of a survey. Enforced automatically (not just a preference) via lifecycle **hooks**, with a `/toaster` skill to toggle it.

## Install (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install.sh | bash
```

Requires `jq` and `curl`. Then open `/hooks` once (or restart Claude Code) to load the hooks in the current session — new sessions pick them up automatically.

## What it installs

| Path | Purpose |
|------|---------|
| `~/.claude/skills/toaster/SKILL.md` | the `/toaster` slash command (toggle + rule statement) |
| `~/.claude/settings.json` → `hooks` | `SessionStart` + `UserPromptSubmit` hooks that inject the rule every chat / every prompt |
| `~/.claude/toaster-mode.off` (flag) | absent = ON (default); present = OFF |

The hooks merge into existing `settings.json` idempotently — re-running the installer never duplicates them.

## Usage

```
/toaster          # status
/toaster off      # disable (verbose replies)
/toaster on       # re-enable
```

Equivalent without the skill:

```bash
touch ~/.claude/toaster-mode.off   # off
rm -f  ~/.claude/toaster-mode.off  # on
```

## How it works

A hook is a shell command Claude Code runs at a lifecycle event. These two fire on `SessionStart` (each new chat) and `UserPromptSubmit` (each message). The command prints the toaster reminder **only if the off-flag is absent**; that stdout is injected into the model's context as a system reminder. Deterministic enforcement, reapplied every turn — which is why it survives a long conversation where a one-time instruction would drift.

## Manual install

No `curl | bash`? Copy `skills/toaster/SKILL.md` to `~/.claude/skills/toaster/`, then merge `settings-hooks-snippet.json` into `~/.claude/settings.json`.

## Optional: memory

`memory/toaster-mode.md` is a Claude Code auto-memory note documenting the rule. Drop it in your project's memory dir if you use that feature.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/uninstall.sh | bash
```
