#!/bin/bash
# install.sh — Install ghostty-notify hook for Claude Code

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$CLAUDE_DIR/ghostty-notify.sh"

# --help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: ./ghostty-notify/install.sh"
  echo ""
  echo "Installs a Stop hook that sends a macOS notification + terminal bell"
  echo "whenever Claude Code finishes and waits for your input."
  echo ""
  echo "Works with any terminal (Ghostty, iTerm2, Kitty, Alacritty, etc.)"
  echo "Requirements: jq (brew install jq)"
  exit 0
fi

# Validate
if [ ! -f "$SCRIPT_DIR/ghostty-notify.sh" ]; then
  echo "Error: Cannot find ghostty-notify.sh in $SCRIPT_DIR"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi

# Copy script
cp "$SCRIPT_DIR/ghostty-notify.sh" "$TARGET"
chmod +x "$TARGET"
echo "Installed: $TARGET"

# Register Stop hook in settings.json
if [ -f "$SETTINGS" ]; then
  if jq -e '.hooks.Stop[]?.hooks[]? | select(.command | contains("ghostty-notify"))' "$SETTINGS" >/dev/null 2>&1; then
    echo "Hook already registered in settings.json (skipped)"
  else
    jq '.hooks = (.hooks // {}) |
        .hooks.Stop = (.hooks.Stop // []) + [{
          "matcher": "",
          "hooks": [{
            "type": "command",
            "command": "'"$TARGET"'",
            "async": true
          }]
        }]' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "Registered Stop hook in: $SETTINGS"
  fi
else
  echo "Warning: $SETTINGS not found. Add the hook manually (see README)."
fi

echo ""
echo "Done! Restart Claude Code to activate."
