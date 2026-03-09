#!/bin/bash
# install.sh — Install Claude usage bar for tmux status line

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.config/tmux/scripts"
TARGET="$TARGET_DIR/claude-usage.sh"
KEYCHAIN_HELPER="$TARGET_DIR/claude-keychain.sh"
TMUX_CONF="$HOME/.config/tmux/tmux.conf"
TMUX_CONF_ALT="$HOME/.tmux.conf"

# --help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: ./tmux-usage/install.sh [OPTIONS]"
  echo ""
  echo "Installs Claude API usage bar for tmux status line."
  echo "Shows 5-hour and weekly rate limit utilization with countdown timers."
  echo ""
  echo "Options:"
  echo "  --theme THEME    Color theme: catppuccin-mocha (default), tokyo-night, nord, gruvbox"
  echo "  --mode MODE      Display mode: all (default), 5h, 7d"
  echo "  --no-tmux-conf   Skip tmux.conf modification"
  echo ""
  echo "Requirements: jq, curl, xxd (all pre-installed on macOS)"
  exit 0
fi

# Parse args
THEME=""
DISPLAY_MODE="all"
SKIP_TMUX_CONF=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme) THEME="$2"; shift 2 ;;
    --mode) DISPLAY_MODE="$2"; shift 2 ;;
    --no-tmux-conf) SKIP_TMUX_CONF=true; shift ;;
    *) shift ;;
  esac
done

# Validate
for file in tmux-usage.sh claude-keychain.sh; do
  if [ ! -f "$SCRIPT_DIR/$file" ]; then
    echo "Error: Cannot find $file in $SCRIPT_DIR"
    exit 1
  fi
done

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi

# Install scripts
mkdir -p "$TARGET_DIR"
cp "$SCRIPT_DIR/tmux-usage.sh" "$TARGET"
cp "$SCRIPT_DIR/claude-keychain.sh" "$KEYCHAIN_HELPER"
chmod +x "$TARGET" "$KEYCHAIN_HELPER"
echo "Installed: $TARGET"
echo "Installed: $KEYCHAIN_HELPER"

# Build the tmux command
TMUX_CMD="$TARGET"
[[ -n "$DISPLAY_MODE" && "$DISPLAY_MODE" != "all" ]] && TMUX_CMD="$TARGET $DISPLAY_MODE"

# Set theme via env var prefix if specified
THEME_PREFIX=""
if [[ -n "$THEME" && "$THEME" != "catppuccin-mocha" ]]; then
  THEME_PREFIX="CLAUDE_TMUX_THEME=$THEME "
fi

FULL_CMD="${THEME_PREFIX}${TMUX_CMD}"
TMUX_LINE="set -ga status-right \" #(${FULL_CMD})\""

if [ "$SKIP_TMUX_CONF" = true ]; then
  echo ""
  echo "Skipped tmux.conf. Add manually:"
  echo "  $TMUX_LINE"
  echo ""
  echo "Done!"
  exit 0
fi

# Find tmux config
CONF=""
if [ -f "$TMUX_CONF" ]; then
  CONF="$TMUX_CONF"
elif [ -f "$TMUX_CONF_ALT" ]; then
  CONF="$TMUX_CONF_ALT"
fi

if [ -n "$CONF" ]; then
  if grep -q "claude-usage" "$CONF" 2>/dev/null; then
    echo "Already present in $CONF (skipped)"
  else
    echo "" >> "$CONF"
    echo "# Claude API usage bar" >> "$CONF"
    echo "$TMUX_LINE" >> "$CONF"
    echo "Registered in: $CONF"
  fi
else
  echo ""
  echo "No tmux.conf found. Add manually to your tmux config:"
  echo "  $TMUX_LINE"
fi

echo ""
echo "Done! Run: tmux source-file ~/.config/tmux/tmux.conf"
