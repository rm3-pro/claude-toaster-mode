# claude-toaster-mode

Make **terse, answer/action-only** replies the permanent default for [Claude Code](https://claude.com/claude-code) — on every machine, every chat.

"Toaster mode" = no preamble, no postamble, no hedging, one recommendation instead of a survey. Enforced automatically (not just a preference) via lifecycle **hooks**, with a `/toaster` skill to toggle it.

**v2 also steers behavior, not just style:** the injected reminder routes broad multi-file searches to an Explore subagent (keeping file dumps out of the main context), drops tool-call narration, and avoids re-reading/re-deriving — cutting the real cost driver (context growth), not just reply length.

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

The reminder is emitted byte-identical every turn, so after the first write it's a cheap prompt-cache read — which is why v2 invests in *behavior* clauses (the real cost lever) rather than throttling the injection to save tokens.

## In the wild

Two prompting habits from people shipping with Claude every day — transcribed here rather than embedded as video. Both rhyme with toaster mode: cut the ceremony, keep the signal.

> **"The most useful prompt I've ever given Claude wasn't for writing code — it was for *deleting* it."**
>
> Senior software engineer by day, vibe coder by night. Every time I finish a feature, I ask Claude to find every piece of dead code, duplicate logic, unused components, or unnecessary complexity it just added. Every single time, it finds something.
>
> Adding features is addictive — you build something new in an hour and feel like a genius, but every feature leaves behind a little mess: unused files, duplicate functions, code that technically works but nobody understands anymore. The longer you build, the more it piles up. Building features is fun; cleaning them up is where the real work starts — and that's the part nobody puts in these videos.
>
> — [**@buildinghappi**](https://www.tiktok.com/@buildinghappi)

> **"I end every AI session with two questions."**
>
> The first: *"What are you least confident about right now? Enumerate everything."* It lists six or seven items — and maybe one in four times there's one that makes you go *why didn't this come up earlier?* Then you tell it to investigate those points exhaustively until it finds root causes and fully understands them.
>
> The second: *"What's the biggest thing I don't realize about this situation right now?"*
>
> Between those two, I get consistently great results.
>
> — [**@geeihadagoodtime**](https://www.tiktok.com/@geeihadagoodtime)

## Optional: HUD statusline

A bundled status line that shows current usage like a HUD:

```
toast:✓ | ⚡sp | tok:143.5k | ctx:142.3k/200k 71% | cmpct:71/95% | 5h:18%/100 7d:33%/100
```

- `toast:` — toaster mode state, **verified** from your settings: `✓` on+enforced, `~` on but last reply ran long (possible drift), `⚠` flag-on but the `UserPromptSubmit` enforcement hook is missing, `✗` off
- `⚡sp` — Superpowers plugin installed **and** enabled (verified via `enabledPlugins` in `settings.json`); shows `sp:✗` if the enable flag is absent/false, hidden if no `settings.json`
- `tok` — tokens burned this session
- `ctx` — context used / max + percent
- `cmpct` — current context % vs the 95% auto-compact trigger (`NOW` at threshold)
- `5h` / `7d` — current 5-hour and weekly usage (Claude.ai subscription auth only; hidden on API-key auth)

Colors escalate green→yellow→red as each climbs. Field paths are the real statusLine stdin contract (`context_window.*`, `rate_limits.{five_hour,seven_day}.used_percentage`).

Install (separate from toaster — won't clobber an existing statusLine silently):

```bash
curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install-statusline.sh | bash
```

## Manual install

No `curl | bash`? Copy `skills/toaster/SKILL.md` to `~/.claude/skills/toaster/`, then merge `settings-hooks-snippet.json` into `~/.claude/settings.json`. For the HUD, copy `statusline.sh` to `~/.claude/statusline.sh` and set `settings.json` `statusLine` to `{"type":"command","command":"bash ~/.claude/statusline.sh"}`.

## Optional: memory

`memory/toaster-mode.md` is a Claude Code auto-memory note documenting the rule. Drop it in your project's memory dir if you use that feature.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/uninstall.sh | bash
```
