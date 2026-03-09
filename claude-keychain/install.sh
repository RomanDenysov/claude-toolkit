#!/bin/bash
# install.sh — Install claude-keychain CLI

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.local/bin/claude-keychain"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: ./claude-keychain/install.sh"
  echo ""
  echo "Installs claude-keychain CLI to ~/.local/bin/"
  echo "Read Claude Code OAuth credentials from macOS Keychain."
  echo ""
  echo "Requirements: jq, xxd (pre-installed on macOS)"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"
cp "$SCRIPT_DIR/claude-keychain" "$TARGET"
chmod +x "$TARGET"
echo "Installed: $TARGET"

if ! echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.local/bin"; then
  echo ""
  echo "Add to your shell profile:"
  echo '  export PATH="$HOME/.local/bin:$PATH"'
fi

echo ""
echo "Done! Try: claude-keychain --help"
