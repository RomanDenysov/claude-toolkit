#!/bin/bash
# claude-keychain.sh — Read Claude Code OAuth credentials from macOS Keychain
#
# macOS Keychain may return credentials as hex-encoded blobs.
# This helper transparently handles both hex and plain JSON formats.
#
# Usage:
#   source claude-keychain.sh
#   data=$(claude_keychain_read)
#   token=$(claude_keychain_token)

claude_keychain_read() {
  local raw
  raw=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
  [[ -z "$raw" ]] && return 1

  if [[ "$raw" =~ ^[0-9a-fA-F]+$ ]] && ! echo "$raw" | jq -e '.' >/dev/null 2>&1; then
    echo "$raw" | xxd -r -p
  else
    echo "$raw"
  fi
}

claude_keychain_token() {
  local data
  data=$(claude_keychain_read) || return 1
  echo "$data" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null
}

claude_keychain_refresh_token() {
  local data
  data=$(claude_keychain_read) || return 1
  echo "$data" | jq -r '.claudeAiOauth.refreshToken // empty' 2>/dev/null
}

claude_keychain_expires_at() {
  local data
  data=$(claude_keychain_read) || return 1
  echo "$data" | jq -r '.claudeAiOauth.expiresAt // empty' 2>/dev/null
}
