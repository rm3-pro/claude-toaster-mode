#!/usr/bin/env bash
# Claude Code statusLine HUD
# Receives JSON on stdin per the statusLine contract.
# Degrades gracefully: missing fields produce no output for that segment.

input=$(cat)

# ── helpers ────────────────────────────────────────────────────────────────────
jqr() { echo "$input" | jq -r "$1 // empty" 2>/dev/null; }
jqn() { echo "$input" | jq -r "$1 // \"\"" 2>/dev/null; }

# ANSI (dimmed palette — status line renders in dim context)
RST='\033[0m'
DIM='\033[2m'
CYN='\033[36m'
YLW='\033[33m'
RED='\033[31m'
GRN='\033[32m'
MAG='\033[35m'

# ── 0. Toaster mode indicator ──────────────────────────────────────────────────
# ✓ = ON and enforcement hook is wired (reminder re-injected every turn)
# ⚠ = enabled by flag but the UserPromptSubmit hook is MISSING — it is NOT being
#     reapplied, so it can silently drift. (verifiable, not a guess)
# ~ = ON and enforced, but the last assistant reply was long — POSSIBLE drift.
#     This is a length heuristic only; long legit answers (code/tables) trip it.
# ✗ = OFF (flag present).
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
toast_seg=""
if [ -f "$CLAUDE_DIR/toaster-mode.off" ]; then
    toast_seg="${DIM}toast:${RST}${RED}✗${RST}"
else
    enforced=""
    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        enforced=$(jq -r '[.hooks.UserPromptSubmit[]?.hooks[]?.command] | any(test("toaster-mode.off"))' "$CLAUDE_DIR/settings.json" 2>/dev/null)
    fi
    if [ "$enforced" != "true" ]; then
        toast_seg="${DIM}toast:${RST}${YLW}⚠${RST}"
    else
        tp=$(jqr '.transcript_path')
        drift=""
        if [ -n "$tp" ] && [ -f "$tp" ]; then
            len=$(tail -n 40 "$tp" | jq -rs 'map(select(.type=="assistant")) | last | (.message.content // []) | map(select(.type=="text").text) | join("") | length' 2>/dev/null)
            [ -n "$len" ] && [ "$len" != "null" ] && [ "$len" -gt 900 ] 2>/dev/null && drift=1
        fi
        if [ -n "$drift" ]; then
            toast_seg="${DIM}toast:${RST}${YLW}~${RST}"
        else
            toast_seg="${DIM}toast:${RST}${GRN}✓${RST}"
        fi
    fi
fi

# ── 1. Tokens burned this session ─────────────────────────────────────────────
# total_input_tokens = cumulative input in context window (includes cache reads/writes)
# total_output_tokens = output tokens from last response
total_in=$(jqr '.context_window.total_input_tokens')
total_out=$(jqr '.context_window.total_output_tokens')

tok_seg=""
if [ -n "$total_in" ] && [ -n "$total_out" ]; then
    # Sum as proxy for "tokens burned this session"
    burned=$(( total_in + total_out ))
    # Format with k suffix
    if [ "$burned" -ge 1000 ]; then
        burned_fmt="$(awk "BEGIN{printf \"%.1fk\", $burned/1000}")"
    else
        burned_fmt="$burned"
    fi
    tok_seg="${CYN}tok:${RST}${burned_fmt}"
elif [ -n "$total_in" ]; then
    if [ "$total_in" -ge 1000 ]; then
        in_fmt="$(awk "BEGIN{printf \"%.1fk\", $total_in/1000}")"
    else
        in_fmt="$total_in"
    fi
    tok_seg="${CYN}tok:${RST}${in_fmt}"
fi

# ── 2. Context window used / max ───────────────────────────────────────────────
ctx_size=$(jqr '.context_window.context_window_size')
used_pct=$(jqr '.context_window.used_percentage')

ctx_seg=""
if [ -n "$ctx_size" ] && [ -n "$total_in" ]; then
    if [ "$ctx_size" -ge 1000 ]; then
        max_fmt="$(awk "BEGIN{printf \"%.0fk\", $ctx_size/1000}")"
    else
        max_fmt="$ctx_size"
    fi
    if [ "$total_in" -ge 1000 ]; then
        used_fmt="$(awk "BEGIN{printf \"%.1fk\", $total_in/1000}")"
    else
        used_fmt="$total_in"
    fi

    # Color by utilisation
    if [ -n "$used_pct" ]; then
        pct_int=$(printf "%.0f" "$used_pct")
        if [ "$pct_int" -ge 85 ]; then
            pct_col="$RED"
        elif [ "$pct_int" -ge 60 ]; then
            pct_col="$YLW"
        else
            pct_col="$GRN"
        fi
        ctx_seg="${DIM}ctx:${RST}${used_fmt}/${max_fmt} ${pct_col}${pct_int}%${RST}"
    else
        ctx_seg="${DIM}ctx:${RST}${used_fmt}/${max_fmt}"
    fi
fi

# ── 3. Compaction tracker ──────────────────────────────────────────────────────
# Auto-compact fires near 95% of the context window.
COMPACT_THRESHOLD=95
compact_seg=""
if [ -n "$used_pct" ]; then
    pct_int=$(printf "%.0f" "$used_pct")
    if [ "$pct_int" -ge "$COMPACT_THRESHOLD" ]; then
        compact_seg="${DIM}cmpct:${RST}${RED}${pct_int}/${COMPACT_THRESHOLD}% NOW${RST}"
    elif [ "$pct_int" -ge 85 ]; then
        cmp_col="$RED"
        compact_seg="${DIM}cmpct:${RST}${cmp_col}${pct_int}${RST}/${COMPACT_THRESHOLD}%"
    elif [ "$pct_int" -ge 70 ]; then
        compact_seg="${DIM}cmpct:${RST}${YLW}${pct_int}${RST}/${COMPACT_THRESHOLD}%"
    else
        compact_seg="${DIM}cmpct:${RST}${GRN}${pct_int}${RST}/${COMPACT_THRESHOLD}%"
    fi
fi

# ── 4 & 5. Rate limits: 5-hour and weekly ─────────────────────────────────────
# Only present for Claude.ai subscribers after first API response.
# Rendered only when the field actually exists; never fabricated.
five_used=$(jqr '.rate_limits.five_hour.used_percentage')
week_used=$(jqr '.rate_limits.seven_day.used_percentage')

rate_seg=""
if [ -n "$five_used" ]; then
    five_int=$(printf "%.0f" "$five_used")
    if [ "$five_int" -ge 90 ]; then
        five_col="$RED"
    elif [ "$five_int" -ge 70 ]; then
        five_col="$YLW"
    else
        five_col="$GRN"
    fi
    rate_seg="${DIM}5h:${RST}${five_col}${five_int}%${RST}/100"
fi

if [ -n "$week_used" ]; then
    week_int=$(printf "%.0f" "$week_used")
    if [ "$week_int" -ge 90 ]; then
        week_col="$RED"
    elif [ "$week_int" -ge 70 ]; then
        week_col="$YLW"
    else
        week_col="$GRN"
    fi
    week_seg="${DIM}7d:${RST}${week_col}${week_int}%${RST}/100"
    rate_seg="${rate_seg:+$rate_seg }${week_seg}"
fi

# ── Assemble ───────────────────────────────────────────────────────────────────
parts=()
[ -n "$toast_seg" ]  && parts+=("$toast_seg")
[ -n "$tok_seg" ]    && parts+=("$tok_seg")
[ -n "$ctx_seg" ]    && parts+=("$ctx_seg")
[ -n "$compact_seg" ] && parts+=("$compact_seg")
[ -n "$rate_seg" ]   && parts+=("$rate_seg")

if [ "${#parts[@]}" -eq 0 ]; then
    exit 0
fi

# Join with separator
out=""
for part in "${parts[@]}"; do
    out="${out:+$out${DIM} | ${RST}}$part"
done

printf "%b\n" "$out"
