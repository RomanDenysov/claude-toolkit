#!/bin/bash
# install.sh — Install auto-skills hook for Claude Code

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check jq
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi

# Copy hook script
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/auto-skills.sh" "$HOOKS_DIR/auto-skills.sh"
chmod +x "$HOOKS_DIR/auto-skills.sh"
echo "Installed hook: $HOOKS_DIR/auto-skills.sh"

# Copy example config if no config exists
if [ ! -f "$CLAUDE_DIR/auto-skills.json" ]; then
  cp "$SCRIPT_DIR/auto-skills.example.json" "$CLAUDE_DIR/auto-skills.json"
  echo "Created config: $CLAUDE_DIR/auto-skills.json"
  echo ""
  echo "  !! Edit ~/.claude/auto-skills.json and update 'skills_library' path !!"
  echo ""
else
  echo "Config already exists: $CLAUDE_DIR/auto-skills.json (skipped)"
fi

# Add SessionStart hook to settings.json
if [ -f "$SETTINGS" ]; then
  # Check if hook already exists
  if jq -e '.hooks.SessionStart[]?.hooks[]? | select(.command | contains("auto-skills"))' "$SETTINGS" >/dev/null 2>&1; then
    echo "Hook already registered in settings.json (skipped)"
  else
    # Add hook to existing settings
    jq '.hooks = (.hooks // {}) |
        .hooks.SessionStart = (.hooks.SessionStart // []) + [{
          "matcher": "startup",
          "hooks": [{
            "type": "command",
            "command": "'"$HOOKS_DIR/auto-skills.sh"'",
            "async": true
          }]
        }]' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "Registered hook in: $SETTINGS"
  fi
else
  echo "Warning: $SETTINGS not found. Add the hook manually (see README)."
fi

echo ""
echo "Done! Restart Claude Code to activate."
echo "Edit ~/.claude/auto-skills.json to configure detection rules."
