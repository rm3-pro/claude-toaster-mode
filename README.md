# toaster-mode

Make **terse, answer/action-only** replies the permanent default for coding agents: Codex, Claude Code, and any future host adapter.

"Toaster mode" = no preamble, no postamble, no hedging, one recommendation instead of a survey. Enforced automatically (not just a preference) via lifecycle **hooks**, with a `/toaster` skill to toggle it.

**v3 steers behavior, not just style:** the injected reminder routes broad multi-file searches to an Explore subagent, drops tool-call narration, avoids re-reading/re-deriving, preserves requested detail for reviews/security/graphify/Obsidian/wiki work, runs cleanup/confidence sweeps before final answers, and keeps secrets out of git.

## Install

### Codex (recommended)

```bash
codex plugin marketplace add rm3-pro/claude-toaster-mode --ref main
codex plugin add toaster-mode@toaster-mode
```

Then open `/hooks`, trust the toaster hooks, and start a new thread. This is the native Codex path and matches how Ponytail, Graphify, and other Codex plugins are loaded.

### Direct installer

```bash
curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install.sh | bash
```

Requires `jq` and `curl`. This remains useful for Claude Code and direct config-level installs. It auto-detects Codex and Claude Code and installs the matching adapter(s). Force a target when needed:

```bash
curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install.sh | TOASTER_HOST=codex bash
curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install.sh | TOASTER_HOST=claude bash
curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install.sh | TOASTER_HOST=all bash
```

Then open `/hooks` once or restart the host so the current session trusts/loads the hooks. New sessions pick them up automatically.

Claude Code can also install it as a plugin from the same repo:

```
/plugin marketplace add rm3-pro/claude-toaster-mode
/plugin install toaster-mode@toaster-mode
```

## What it installs

| Path | Purpose |
|------|---------|
| `.agents/plugins/marketplace.json` | Codex marketplace entry for GitHub install |
| `.codex-plugin/plugin.json` | Codex plugin manifest |
| `.claude-plugin/plugin.json` | Claude plugin manifest |
| `.claude-plugin/marketplace.json` | Claude marketplace entry |
| `hooks/claude-codex-hooks.json` | Plugin `SessionStart` + `UserPromptSubmit` hooks |
| `hooks/toaster-hook.js` | Plugin hook runtime for Codex/Claude |
| `$PLUGIN_DATA/.toaster-mode.off` (flag) | Codex plugin off switch; absent = ON |
| `${CODEX_HOME:-~/.codex}/skills/toaster/SKILL.md` | Codex direct-install toaster skill/rules |
| `${CODEX_HOME:-~/.codex}/hooks/toaster-codex-hook.sh` | Codex direct-install hook script |
| `${CODEX_HOME:-~/.codex}/hooks.json` → `hooks` | Codex direct-install hooks |
| `${CODEX_HOME:-~/.codex}/toaster-mode.off` (flag) | Codex direct-install off switch; absent = ON |
| `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/toaster/SKILL.md` | the `/toaster` slash command (toggle + rule statement) |
| `${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json` → `hooks` | Claude Code `SessionStart` + `UserPromptSubmit` hooks |
| `${CLAUDE_CONFIG_DIR:-~/.claude}/toaster-mode.off` (flag) | Claude Code off switch; absent = ON |

Hooks merge idempotently. Re-running the installer does not duplicate them.

## Usage

```
/toaster          # status
/toaster off      # disable (verbose replies)
/toaster on       # re-enable
```

Equivalent without the skill:

```bash
touch "${CODEX_HOME:-$HOME/.codex}/toaster-mode.off"              # Codex off
rm -f  "${CODEX_HOME:-$HOME/.codex}/toaster-mode.off"             # Codex on
touch "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/toaster-mode.off"      # Claude Code off
rm -f  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/toaster-mode.off"     # Claude Code on
```

## How it works

Each host adapter wires lifecycle hooks for `SessionStart` and `UserPromptSubmit`. Codex uses the plugin manifest and hook trust flow; Claude/direct installs use config-level hooks. The hook emits the toaster reminder **only if the off-flag is absent**; the host injects that output into the model context as a system reminder. Deterministic enforcement, reapplied every turn — which is why it survives a long conversation where a one-time instruction would drift.

The reminder is emitted byte-identical every turn, so after the first write it's a cheap prompt-cache read — which is why v3 invests in *behavior* clauses (the real cost lever) rather than throttling the injection to save tokens.

## In the wild

Habits from people shipping with agents every day — transcribed here rather than embedded as video. They now map directly to behavior modifiers in the injected reminder: delete sweep, confidence/root-cause sweep, and secrets baseline.

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

> **"If you're getting into vibe coding: you cannot store your API keys in your GitHub."**
>
> Tell the agent building your app to put secrets in a `.env` file — and keep that file out of the repo. Your API keys (and anything sensitive, like payment methods) live wherever you host the app, as environment variables outside the codebase; the app reads them at runtime. It's not foolproof — hackers are getting more capable with these tools too — but it's the baseline that keeps you from setting yourself up for failure from the start.
>
> — [**@theaiconsultinglab**](https://www.tiktok.com/@theaiconsultinglab)

## Optional: Claude HUD statusline

A bundled Claude Code status line that shows current usage like a HUD:

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

## Optional: Codex native statusline

Codex does **not** run Claude Code's `statusLine.command` shell contract. It has a native TUI footer configured by `/statusline` or by `[tui].status_line` in `${CODEX_HOME:-~/.codex}/config.toml`.

Use this for the Codex equivalent:

```bash
curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/install-codex-statusline.sh | bash
```

It sets a compact always-visible footer:

```toml
[tui]
status_line = ["model-with-reasoning", "context-remaining", "five-hour-limit", "weekly-limit", "used-tokens", "git-branch", "task-progress", "current-dir"]
```

You can still run `/statusline` inside Codex to reorder fields, hide fields, or use the interactive picker. The Codex footer is native; the Claude HUD script remains Claude-only.

## Manual install

No `curl | bash`?

- Codex plugin: use `codex plugin marketplace add rm3-pro/claude-toaster-mode --ref main`, then `codex plugin add toaster-mode@toaster-mode`, then trust hooks with `/hooks`.
- Codex direct: copy `skills/toaster/SKILL.md` to `${CODEX_HOME:-~/.codex}/skills/toaster/`, copy `hooks/toaster-codex-hook.sh` to `${CODEX_HOME:-~/.codex}/hooks/`, then merge a `SessionStart` and `UserPromptSubmit` command hook into `${CODEX_HOME:-~/.codex}/hooks.json`.
- Claude Code: copy `skills/toaster/SKILL.md` to `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/toaster/`, then merge `settings-hooks-snippet.json` into `${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json`.
- Claude HUD: copy `statusline.sh` to `${CLAUDE_CONFIG_DIR:-~/.claude}/statusline.sh` and set `settings.json` `statusLine` to run that script.
- Codex footer: add the `[tui].status_line` TOML shown above to `${CODEX_HOME:-~/.codex}/config.toml`.

## Optional: memory

`memory/toaster-mode.md` is an optional memory note documenting the rule. Drop it in a host/project memory directory if you use that feature.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/rm3-pro/claude-toaster-mode/main/uninstall.sh | bash
codex plugin remove toaster-mode
```
