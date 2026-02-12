#!/bin/bash
# ghostty-notify.sh — macOS notification when Claude Code needs input
# Triggered by the "Stop" hook

set -euo pipefail

# Extract project dir from hook JSON stdin
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
project="${cwd##*/}"

title="Claude Code"
message="${project:+[$project] }Waiting for your input"

# macOS notification with sound
osascript -e "display notification \"$message\" with title \"$title\" sound name \"Tink\"" 2>/dev/null || true

# Terminal bell (works in Ghostty, iTerm2, Kitty, etc.)
printf '\a'

exit 0
