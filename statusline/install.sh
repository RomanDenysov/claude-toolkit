#!/bin/bash
# install.sh — Install the statusline for Claude Code

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$CLAUDE_DIR/statusline.sh"

# --help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: ./statusline/install.sh"
  echo ""
  echo "Installs the Tokyo Night statusline for Claude Code."
  echo "Shows: directory, git branch/status, model, context usage,"
  echo "       tasks, MCP servers, session duration, and cost."
  echo ""
  echo "Requirements: jq (brew install jq)"
  echo "Optional: gdate (brew install coreutils) for session duration"
  exit 0
fi

# Validate
if [ ! -f "$SCRIPT_DIR/statusline.sh" ]; then
  echo "Error: Cannot find statusline.sh in $SCRIPT_DIR"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi

# Copy script
cp "$SCRIPT_DIR/statusline.sh" "$TARGET"
chmod +x "$TARGET"
echo "Installed: $TARGET"

# Register in settings.json
if [ -f "$SETTINGS" ]; then
  CURRENT=$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null)
  if [ "$CURRENT" = "$TARGET" ]; then
    echo "Already registered in settings.json (skipped)"
  else
    if [ -n "$CURRENT" ]; then
      echo "Replacing existing statusline: $CURRENT"
    fi
    jq --arg cmd "$TARGET" '.statusLine = {type: "command", command: $cmd}' \
      "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "Registered in: $SETTINGS"
  fi
else
  echo "Warning: $SETTINGS not found. Add manually:"
  echo '  "statusLine": {"type": "command", "command": "'"$TARGET"'"}'
fi

echo ""
echo "Done! Restart Claude Code to activate."
