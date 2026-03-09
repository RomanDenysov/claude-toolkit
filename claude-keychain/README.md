# claude-keychain

CLI to read Claude Code OAuth credentials from macOS Keychain.

Handles the hex-encoded data blob format that macOS Keychain uses when returning credentials via `security -w`.

## Commands

```bash
claude-keychain token           # Print access token
claude-keychain refresh-token   # Print refresh token
claude-keychain expires         # "3h42m" or "expired"
claude-keychain expired         # Exit 0 if expired, 1 if valid
claude-keychain subscription    # "pro", "max", etc.
claude-keychain read            # Full credentials JSON
claude-keychain field <name>    # Any field from claudeAiOauth
```

## Use in Scripts

```bash
# Auth header for API calls
curl -H "Authorization: Bearer $(claude-keychain token)" \
  https://api.anthropic.com/api/oauth/usage

# Check if token needs refresh
if claude-keychain expired; then
  echo "Token expired, run /login in Claude Code"
fi

# Get rate limit tier
claude-keychain field rateLimitTier
```

## Why This Exists

macOS Keychain stores Claude Code credentials as data blobs. When read via `security find-generic-password -w`, this returns a hex-encoded string instead of plain JSON. Most scripts that try to parse the output with `jq` or `grep` silently fail.

This tool detects the encoding and decodes transparently.

## Install

```bash
cd claude-toolkit
chmod +x claude-keychain/install.sh
./claude-keychain/install.sh
```

Installs to `~/.local/bin/claude-keychain`.

## Requirements

- macOS
- `jq` — `brew install jq`
- `xxd` — pre-installed on macOS
- Claude Code with OAuth login
