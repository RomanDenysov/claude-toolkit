#!/bin/bash
# tmux-usage.sh - Claude API usage bar for tmux status line
#
# Shows 5-hour and 7-day rate limit utilization with countdown timers.
# Read-only - reads OAuth credentials from macOS Keychain, never modifies them.
# Token refresh is handled by Claude Code itself.
#
# Usage: tmux-usage.sh [5h|7d|all]
#   5h  - show only 5-hour limit
#   7d  - show only weekly limit
#   all - show both (default)

MODE="${1:-all}"

CACHE_DIR="$HOME/.cache/claude-tmux-usage"
API_CACHE="$CACHE_DIR/api-response.json"
NOW=$(date +%s)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[[ ! -d "$CACHE_DIR" ]] && mkdir -p "$CACHE_DIR"
source "$SCRIPT_DIR/claude-keychain.sh"

# ─── Theme ────────────────────────────────────────────────────────────────────
# Override by setting CLAUDE_TMUX_THEME before calling, or edit defaults here.
# Expects tmux style format: #[fg=...,bg=...]
#
# Built-in themes: catppuccin-mocha (default), tokyo-night, nord, gruvbox
# Custom: set CLAUDE_TMUX_BG, CLAUDE_TMUX_RED, etc. directly

setup_theme() {
  local theme="${CLAUDE_TMUX_THEME:-catppuccin-mocha}"

  # Allow full override via env vars
  if [[ -n "${CLAUDE_TMUX_BG:-}" ]]; then
    C_BG="$CLAUDE_TMUX_BG"
    C_RED="#[fg=${CLAUDE_TMUX_RED:-#f38ba8},bg=${C_BG}]"
    C_YELLOW="#[fg=${CLAUDE_TMUX_YELLOW:-#f9e2af},bg=${C_BG}]"
    C_GREEN="#[fg=${CLAUDE_TMUX_GREEN:-#a6e3a1},bg=${C_BG}]"
    C_GRAY="#[fg=${CLAUDE_TMUX_GRAY:-#6c7086},bg=${C_BG}]"
    C_RESET="#[fg=${CLAUDE_TMUX_FG:-#cdd6f4},bg=${C_BG}]"
    return
  fi

  case "$theme" in
    catppuccin-mocha)
      C_BG="#1e1e2e"
      C_RED="#[fg=#f38ba8,bg=${C_BG}]"  C_YELLOW="#[fg=#f9e2af,bg=${C_BG}]"
      C_GREEN="#[fg=#a6e3a1,bg=${C_BG}]" C_GRAY="#[fg=#6c7086,bg=${C_BG}]"
      C_RESET="#[fg=#cdd6f4,bg=${C_BG}]"
      ;;
    tokyo-night)
      C_BG="#1a1b26"
      C_RED="#[fg=#f7768e,bg=${C_BG}]"  C_YELLOW="#[fg=#e0af68,bg=${C_BG}]"
      C_GREEN="#[fg=#9ece6a,bg=${C_BG}]" C_GRAY="#[fg=#565f89,bg=${C_BG}]"
      C_RESET="#[fg=#a9b1d6,bg=${C_BG}]"
      ;;
    nord)
      C_BG="#2e3440"
      C_RED="#[fg=#bf616a,bg=${C_BG}]"  C_YELLOW="#[fg=#ebcb8b,bg=${C_BG}]"
      C_GREEN="#[fg=#a3be8c,bg=${C_BG}]" C_GRAY="#[fg=#4c566a,bg=${C_BG}]"
      C_RESET="#[fg=#d8dee9,bg=${C_BG}]"
      ;;
    gruvbox)
      C_BG="#282828"
      C_RED="#[fg=#fb4934,bg=${C_BG}]"  C_YELLOW="#[fg=#fabd2f,bg=${C_BG}]"
      C_GREEN="#[fg=#b8bb26,bg=${C_BG}]" C_GRAY="#[fg=#665c54,bg=${C_BG}]"
      C_RESET="#[fg=#ebdbb2,bg=${C_BG}]"
      ;;
    *)
      C_BG="#1e1e2e"
      C_RED="#[fg=#f38ba8,bg=${C_BG}]"  C_YELLOW="#[fg=#f9e2af,bg=${C_BG}]"
      C_GREEN="#[fg=#a6e3a1,bg=${C_BG}]" C_GRAY="#[fg=#6c7086,bg=${C_BG}]"
      C_RESET="#[fg=#cdd6f4,bg=${C_BG}]"
      ;;
  esac
}

setup_theme

# ─── Helpers ──────────────────────────────────────────────────────────────────

get_pct_color() {
  local pct="$1"
  if [[ $pct -gt 80 ]]; then echo "$C_RED"
  elif [[ $pct -gt 60 ]]; then echo "$C_YELLOW"
  else echo "$C_GREEN"; fi
}

make_bar() {
  local pct="$1" color="$2" width=10
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  [[ $filled -gt $width ]] && filled=$width
  [[ $filled -lt 0 ]] && filled=0
  [[ $empty -lt 0 ]] && empty=0
  local bar_f=$(printf '%*s' "$filled" '' | tr ' ' '▓')
  local bar_e=$(printf '%*s' "$empty" '' | tr ' ' '░')
  printf "%s[%s%s%s%s%s]%s" "$C_GRAY" "$C_RESET" "$color" "$bar_f" "$C_GRAY" "$bar_e" "$C_RESET"
}

format_time() {
  local s="$1"
  [[ $s -le 0 ]] && echo "0m" && return
  local h=$((s / 3600)) m=$(((s % 3600) / 60))
  [[ $h -gt 0 ]] && echo "${h}h${m}m" || echo "${m}m"
}

format_time_days() {
  local s="$1"
  [[ $s -le 0 ]] && echo "0m" && return
  local d=$((s / 86400)) h=$(((s % 86400) / 3600)) m=$(((s % 3600) / 60))
  if [[ $d -gt 0 ]]; then echo "${d}d${h}h"
  elif [[ $h -gt 0 ]]; then echo "${h}h${m}m"
  else echo "${m}m"; fi
}

parse_reset_seconds() {
  local iso="$1"
  [[ -z "$iso" ]] && return 1
  local clean=$(echo "$iso" | sed 's/\.[0-9]*//; s/+00:00//; s/Z$//')
  local ts
  ts=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" 2>/dev/null) || return 1
  echo $(( ts - NOW ))
}

# ─── API ──────────────────────────────────────────────────────────────────────

fetch_api_data() {
  # Cache hit (60s TTL)
  if [[ -f "$API_CACHE" ]]; then
    local mod_time
    mod_time=$(stat -f '%m' "$API_CACHE" 2>/dev/null) || { cat "$API_CACHE"; return 0; }
    [[ $((NOW - mod_time)) -lt 60 ]] && cat "$API_CACHE" && return 0
  fi

  local token
  token=$(claude_keychain_token)
  [[ -z "$token" ]] && { [[ -f "$API_CACHE" ]] && cat "$API_CACHE"; return 0; }

  local response
  response=$(curl -s --max-time 5 "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer ${token}" \
    -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)

  # Validate: must be JSON with usage data
  if [[ -n "$response" ]] && echo "$response" | jq -e '.five_hour or .seven_day' >/dev/null 2>&1; then
    echo "$response" > "$API_CACHE"
    echo "$response"
  else
    # Token expired or API error - show stale cache, let Claude Code handle refresh
    [[ -f "$API_CACHE" ]] && cat "$API_CACHE"
  fi
}

# ─── Formatters ───────────────────────────────────────────────────────────────

format_5h() {
  local pct="$1" reset_at="$2"
  [[ -z "$pct" ]] && return

  local pct_int=${pct%.*}
  local color=$(get_pct_color "$pct_int")
  local bar=$(make_bar "$pct_int" "$color")

  local label="5h"
  local secs
  if secs=$(parse_reset_seconds "$reset_at"); then
    label=$(format_time "$secs")
  fi

  printf "%s: %s %s%s%%%s" "$label" "$bar" "$color" "$pct_int" "$C_RESET"
}

format_7d() {
  local pct="$1" reset_at="$2"
  [[ -z "$pct" ]] && return

  local pct_int=${pct%.*}
  local color=$(get_pct_color "$pct_int")
  local bar=$(make_bar "$pct_int" "$color")

  local label="7d"
  local secs
  if secs=$(parse_reset_seconds "$reset_at"); then
    label=$(format_time_days "$secs")
  fi

  printf "%s%s:%s %s %s%s%%%s" "$C_GRAY" "$label" "$C_RESET" "$bar" "$color" "$pct_int" "$C_RESET"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

RESPONSE=$(fetch_api_data)
[[ -z "$RESPONSE" ]] && exit 0

# Single jq call to extract all fields at once
IFS='|' read -r is_err pct_5h reset_5h pct_7d reset_7d has_5h <<< "$(
  echo "$RESPONSE" | jq -r '[
    (if .error then "1" else "0" end),
    (.five_hour.utilization // "" | tostring),
    (.five_hour.resets_at // ""),
    (.seven_day.utilization // "" | tostring),
    (.seven_day.resets_at // ""),
    (if has("five_hour") then "1" else "0" end)
  ] | join("|")' 2>/dev/null
)"

# Error or unparseable response
if [[ "$is_err" == "1" || -z "$is_err" ]]; then
  rm -f "$API_CACHE"
  echo "${C_RED}⚠ Auth${C_RESET}"
  exit 0
fi

# No utilization data - unlimited or auth error
if [[ -z "$pct_5h" && -z "$pct_7d" ]]; then
  if [[ "$has_5h" == "1" ]]; then
    echo "${C_GREEN}∞ Max${C_RESET}"
  else
    rm -f "$API_CACHE"
    echo "${C_RED}⚠ Auth${C_RESET}"
  fi
  exit 0
fi

# Render
case "$MODE" in
  5h)  format_5h "$pct_5h" "$reset_5h" ;;
  7d)  format_7d "$pct_7d" "$reset_7d" ;;
  all|*)
    out_5h=$(format_5h "$pct_5h" "$reset_5h")
    out_7d=$(format_7d "$pct_7d" "$reset_7d")
    if [[ -n "$out_5h" && -n "$out_7d" ]]; then
      echo "${out_5h} ${C_GRAY}│${C_RESET} ${out_7d}"
    elif [[ -n "$out_5h" ]]; then echo "$out_5h"
    elif [[ -n "$out_7d" ]]; then echo "$out_7d"
    fi
    ;;
esac
