#!/bin/bash

# Tokyo Night Storm palette
C_RED="\033[38;2;247;118;142m"
C_YELLOW="\033[38;2;224;175;104m"
C_GREEN="\033[38;2;158;206;106m"
C_CYAN="\033[38;2;125;207;255m"
C_BLUE="\033[38;2;122;162;247m"
C_PURPLE="\033[38;2;187;154;247m"
C_GRAY="\033[38;2;86;95;137m"
C_WHITE="\033[38;2;169;177;214m"
C_RESET="\033[0m"

# Read JSON input from stdin
input=$(cat)

# ═══════════════════════════════════════════════════════════════════════════════
# 1. DIRECTORY PATH (shortened with parent/current coloring)
# ═══════════════════════════════════════════════════════════════════════════════
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')

short_dir=$(echo "$current_dir" | awk -F'/' '{n = NF; if (n <= 3) print $0; else printf "…/%s/%s/%s", $(n-2), $(n-1), $n}')
dir_parent=$(dirname "$short_dir")
dir_name=$(basename "$short_dir")
dir_part=$(printf "${C_GRAY}${dir_parent}/${C_PURPLE}${dir_name}${C_RESET}")

# ═══════════════════════════════════════════════════════════════════════════════
# 2. GIT BRANCH + STATUS + WORKTREE INDICATOR
# ═══════════════════════════════════════════════════════════════════════════════
git_part=""
worktree_indicator=""
if git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    # Check if this is a worktree (not the main repo)
    git_dir=$(git -C "$current_dir" rev-parse --git-dir 2>/dev/null)
    if [ -f "$current_dir/.git" ] || [[ "$git_dir" == *"/worktrees/"* ]]; then
        worktree_indicator="${C_BLUE}⎔${C_RESET} "
    fi

    git_branch=$(git -C "$current_dir" --no-optional-locks branch --show-current 2>/dev/null)
    if [ -n "$git_branch" ]; then
        # Check for uncommitted changes
        if git -C "$current_dir" --no-optional-locks diff-index --quiet HEAD 2>/dev/null; then
            git_status="${C_GREEN}✓${C_RESET}"
        else
            git_status="${C_RED}✗${C_RESET}"
        fi

        # Check for unpushed commits
        unpushed=$(git -C "$current_dir" --no-optional-locks rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
        if [ "$unpushed" -gt 0 ]; then
            unpushed_indicator="${C_YELLOW}↑${unpushed}${C_RESET}"
        else
            unpushed_indicator=""
        fi

        git_part=$(printf " ${C_GRAY}│${C_CYAN} ${worktree_indicator} ${git_branch} ${git_status}${unpushed_indicator}")
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 3. MODEL INDICATOR (compact icon)
# ═══════════════════════════════════════════════════════════════════════════════
model=$(echo "$input" | jq -r '.model // ""')
model_display=$(echo "$input" | jq -r '.model_display_name // ""')
model_part=""

case "$model" in
    *opus*|*Opus*)
        model_icon="${C_PURPLE}◆${C_RESET}"
        model_short="opus"
        ;;
    *sonnet*|*Sonnet*)
        model_icon="${C_BLUE}◇${C_RESET}"
        model_short="sonnet"
        ;;
    *haiku*|*Haiku*)
        model_icon="${C_CYAN}○${C_RESET}"
        model_short="haiku"
        ;;
    *)
        if [ -n "$model_display" ]; then
            model_icon="${C_WHITE}●${C_RESET}"
            model_short=$(echo "$model_display" | cut -c1-8)
        else
            model_icon=""
            model_short=""
        fi
        ;;
esac

if [ -n "$model_icon" ]; then
    model_part=$(printf " ${C_GRAY}│${C_RESET} ${model_icon} ${C_WHITE}${model_short}${C_RESET}")
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 4. CONTEXT WINDOW USAGE (progress bar + remaining)
# ═══════════════════════════════════════════════════════════════════════════════
context_part=""
usage=$(echo "$input" | jq '.context_window.current_usage')
size=$(echo "$input" | jq '.context_window.context_window_size')

if [ "$size" != "null" ] && [ "$size" != "0" ]; then
    if [ "$usage" != "null" ]; then
        current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    else
        current=0
    fi

    # Autocompact triggers at 77.5% (100% - 22.5% buffer)
    autocompact_threshold=$((size * 775 / 1000))
    pct=$((current * 100 / autocompact_threshold))
    remaining=$((autocompact_threshold - current))

    [ $remaining -lt 0 ] && remaining=0 && pct=100
    [ $pct -gt 100 ] && pct=100

    # Format tokens (e.g., 110k)
    if [ $remaining -ge 1000 ]; then
        remaining_fmt="$((remaining / 1000))k"
    else
        remaining_fmt="$remaining"
    fi
    if [ $current -ge 1000 ]; then
        current_fmt="$((current / 1000))k"
    else
        current_fmt="$current"
    fi

    # Dynamic color based on percentage
    if [ $pct -gt 80 ]; then
        pct_color="$C_RED"
    elif [ $pct -gt 60 ]; then
        pct_color="$C_YELLOW"
    else
        pct_color="$C_GREEN"
    fi

    # Progress bar (10 chars wide)
    bar_width=10
    filled=$((pct * bar_width / 100))
    empty=$((bar_width - filled))
    [ $filled -gt $bar_width ] && filled=$bar_width
    [ $filled -lt 0 ] && filled=0
    [ $empty -lt 0 ] && empty=0

    bar_filled=$(printf '%*s' "$filled" '' | tr ' ' '▓')
    bar_empty=$(printf '%*s' "$empty" '' | tr ' ' '░')
    progress_bar="${pct_color}${bar_filled}${C_GRAY}${bar_empty}${C_RESET}"

    context_part=$(printf " ${C_GRAY}│${C_RESET} ${pct_color}${pct}%%${C_RESET}: ${current_fmt}${C_GRAY}[${C_RESET}${progress_bar}${C_GRAY}]${C_RESET}${remaining_fmt}")
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 5. ACTIVE TASKS (Todo List)
# ═══════════════════════════════════════════════════════════════════════════════
task_part=""
pending=$(echo "$input" | jq '[.todo_list[]? | select(.status == "pending")] | length // 0' 2>/dev/null)
in_progress=$(echo "$input" | jq '[.todo_list[]? | select(.status == "in_progress")] | length // 0' 2>/dev/null)

[ "$pending" = "null" ] || [ -z "$pending" ] && pending=0
[ "$in_progress" = "null" ] || [ -z "$in_progress" ] && in_progress=0

if [ "$in_progress" -gt 0 ] || [ "$pending" -gt 0 ]; then
    if [ "$in_progress" -gt 0 ]; then
        task_part=$(printf " ${C_GRAY}│${C_YELLOW} ⏳${in_progress}${C_GRAY}/${C_WHITE}${pending}${C_RESET}")
    else
        task_part=$(printf " ${C_GRAY}│${C_WHITE} 📋${pending}${C_RESET}")
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 6. MCP SERVERS CONNECTED
# ═══════════════════════════════════════════════════════════════════════════════
mcp_part=""
mcp_count=$(echo "$input" | jq '.mcp_servers | length // 0' 2>/dev/null)
[ "$mcp_count" = "null" ] || [ -z "$mcp_count" ] && mcp_count=0

if [ "$mcp_count" -gt 0 ]; then
    mcp_part=$(printf " ${C_GRAY}│${C_CYAN} ⚡${mcp_count}${C_RESET}")
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 7. SESSION DURATION
# ═══════════════════════════════════════════════════════════════════════════════
duration_part=""
session_start=$(echo "$input" | jq -r '.session.start_time // empty' 2>/dev/null)

if [ -n "$session_start" ] && [ "$session_start" != "null" ]; then
    if command -v gdate > /dev/null 2>&1; then
        start_epoch=$(gdate -d "$session_start" +%s 2>/dev/null || echo "")
        now_epoch=$(gdate +%s)
    else
        start_epoch=$(python3 -c "from datetime import datetime; print(int(datetime.fromisoformat('$session_start'.replace('Z','+00:00')).timestamp()))" 2>/dev/null || echo "")
        now_epoch=$(date +%s)
    fi

    if [ -n "$start_epoch" ]; then
        elapsed=$((now_epoch - start_epoch))

        if [ $elapsed -ge 3600 ]; then
            hours=$((elapsed / 3600))
            mins=$(((elapsed % 3600) / 60))
            duration_fmt="${hours}h${mins}m"
        elif [ $elapsed -ge 60 ]; then
            mins=$((elapsed / 60))
            duration_fmt="${mins}m"
        else
            duration_fmt="${elapsed}s"
        fi

        duration_part=$(printf " ${C_GRAY}│ ⏱${C_WHITE}${duration_fmt}${C_RESET}")
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 8. SESSION COST
# ═══════════════════════════════════════════════════════════════════════════════
cost_part=""
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

if [ "$cost" != "0" ] && [ "$cost" != "null" ] && [ -n "$cost" ]; then
    cost_fmt=$(printf "%.2f" "$cost")
    cost_part=$(printf " ${C_GRAY}│ ${C_YELLOW}\$${cost_fmt}${C_RESET}")
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PRINT COMPLETE STATUS LINE
# ═══════════════════════════════════════════════════════════════════════════════
echo -n "${dir_part}${git_part}${model_part}${context_part}${task_part}${mcp_part}${duration_part}${cost_part}"
