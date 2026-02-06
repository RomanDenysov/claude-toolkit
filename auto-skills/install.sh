#!/bin/bash
# install.sh — Install auto-skills hook for Claude Code

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --help
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: ./auto-skills/install.sh"
  echo ""
  echo "Installs the auto-skills SessionStart hook for Claude Code."
  echo "Auto-detects your installed skills and generates detection rules."
  echo ""
  echo "Requirements: jq (brew install jq)"
  exit 0
fi

# Validate we're in the right directory
if [ ! -f "$SCRIPT_DIR/auto-skills.sh" ]; then
  echo "Error: Cannot find auto-skills.sh in $SCRIPT_DIR"
  echo "Make sure you're running this from the claude-toolkit repo."
  exit 1
fi

# Check jq
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi

# --- Auto-detect skills library ---

find_skills_library() {
  for candidate in \
    "$HOME/.agents/skills" \
    "$HOME/.claude/skills-library" \
    "$HOME/.claude/skills" \
    ; do
    if [ -d "$candidate" ] && [ "$(ls -A "$candidate" 2>/dev/null)" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

SKILLS_LIBRARY=""
if SKILLS_LIBRARY=$(find_skills_library); then
  echo "Found skills library: $SKILLS_LIBRARY"
else
  echo ""
  echo "Could not auto-detect skills library."
  echo "Common locations: ~/.agents/skills, ~/.claude/skills-library"
  echo ""
  read -p "Enter path to your skills directory: " SKILLS_LIBRARY
  if [ ! -d "$SKILLS_LIBRARY" ]; then
    echo "Error: $SKILLS_LIBRARY is not a directory"
    exit 1
  fi
fi

# --- Known skill detection rules ---
# Each function outputs a jq-compatible rule JSON for a skill if it exists.
# To add support for a new skill, add its name to the case statement below.

skill_rule() {
  local skill="$1"
  local files=""
  local deps=""

  case "$skill" in
    turborepo)
      files='["turbo.json"]'; deps='[]' ;;
    building-native-ui)
      files='["app.json","expo.json"]'; deps='["expo"]' ;;
    update-docs)
      files='["next.config.js","next.config.mjs","next.config.ts"]'; deps='["next"]' ;;
    vercel-react-best-practices)
      files='[]'; deps='["react"]' ;;
    agent-browser)
      files='["playwright.config.ts","playwright.config.js","cypress.config.ts","cypress.config.js"]'; deps='["playwright","puppeteer","cypress"]' ;;
    # --- Languages & frameworks ---
    swift-*|ios-*)
      files='["Package.swift","*.xcodeproj","*.xcworkspace"]'; deps='[]' ;;
    django-*)
      files='["manage.py"]'; deps='["django"]' ;;
    flask-*)
      files='["app.py"]'; deps='["flask"]' ;;
    rails-*)
      files='["Gemfile","Rakefile"]'; deps='[]' ;;
    go-*)
      files='["go.mod"]'; deps='[]' ;;
    rust-*)
      files='["Cargo.toml"]'; deps='[]' ;;
    vue-*)
      files='["vue.config.js"]'; deps='["vue"]' ;;
    angular-*)
      files='["angular.json"]'; deps='["@angular/core"]' ;;
    svelte-*)
      files='["svelte.config.js","svelte.config.ts"]'; deps='["svelte"]' ;;
    # --- Tooling ---
    tailwind-*|tailwindcss-*)
      files='["tailwind.config.js","tailwind.config.ts"]'; deps='["tailwindcss"]' ;;
    prisma-*)
      files='["prisma/schema.prisma"]'; deps='["@prisma/client"]' ;;
    drizzle-*)
      files='["drizzle.config.ts","drizzle.config.js"]'; deps='["drizzle-orm"]' ;;
    docker-*)
      files='["Dockerfile","docker-compose.yml","docker-compose.yaml"]'; deps='[]' ;;
    terraform-*)
      files='["main.tf"]'; deps='[]' ;;
    *)
      return 1 ;;
  esac

  jq -n \
    --arg name "$skill" \
    --argjson files "$files" \
    --argjson deps "$deps" \
    '{name: $name, detect: {files: $files, deps: $deps}, skills: [$name], plugins: {}}'
}

# --- Generate config from installed skills ---

generate_config() {
  local skills_lib="$1"
  local rules="[]"
  local unmatched=""
  local count=0

  for skill_dir in "$skills_lib"/*/; do
    [ -d "$skill_dir" ] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")

    # find-skills goes to always_enabled, skip rule generation
    [ "$skill_name" = "find-skills" ] && continue

    local rule=""
    if rule=$(skill_rule "$skill_name"); then
      rules=$(echo "$rules" | jq --argjson r "$rule" '. + [$r]')
      count=$((count + 1))
      echo "  + $skill_name" >&2
    else
      unmatched="$unmatched $skill_name"
    fi
  done

  # Merge rules that share the same detection signals
  rules=$(echo "$rules" | jq '
    group_by(.detect) |
    map({
      name: (map(.name) | join("+")),
      detect: .[0].detect,
      skills: [.[].skills[]] | unique,
      plugins: (map(.plugins) | add)
    })
  ')

  # Output final config JSON
  jq -n \
    --arg lib "$skills_lib" \
    --argjson rules "$rules" \
    '{
      skills_library: $lib,
      rules: $rules,
      always_enabled: {
        skills: ["find-skills"],
        plugins: {}
      }
    }'

  echo "" >&2
  echo "Generated $count detection rules." >&2
  if [ -n "$unmatched" ]; then
    echo "Skills without auto-detection rules (add manually to ~/.claude/auto-skills.json):" >&2
    for s in $unmatched; do
      echo "  ? $s" >&2
    done
  fi
}

# --- Install ---

# 1. Copy hook script
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/auto-skills.sh" "$HOOKS_DIR/auto-skills.sh"
chmod +x "$HOOKS_DIR/auto-skills.sh"
echo "Installed hook: $HOOKS_DIR/auto-skills.sh"

# 2. Generate config (or skip if exists)
if [ ! -f "$CLAUDE_DIR/auto-skills.json" ]; then
  echo ""
  echo "Scanning installed skills..."

  # generate_config prints JSON to stdout, status to stderr
  if CONFIG_JSON=$(generate_config "$SKILLS_LIBRARY"); then
    echo "$CONFIG_JSON" | jq '.' > "$CLAUDE_DIR/auto-skills.json"
    echo "Saved config: $CLAUDE_DIR/auto-skills.json"
  else
    echo "Warning: Config generation failed, using example config."
    cp "$SCRIPT_DIR/auto-skills.example.json" "$CLAUDE_DIR/auto-skills.json"
    jq --arg lib "$SKILLS_LIBRARY" '.skills_library = $lib' \
      "$CLAUDE_DIR/auto-skills.json" > "$CLAUDE_DIR/auto-skills.json.tmp" \
      && mv "$CLAUDE_DIR/auto-skills.json.tmp" "$CLAUDE_DIR/auto-skills.json"
  fi
else
  echo "Config already exists: $CLAUDE_DIR/auto-skills.json (skipped)"
  echo "  To regenerate, delete it and re-run: rm ~/.claude/auto-skills.json"
fi

# 3. Register SessionStart hook
if [ -f "$SETTINGS" ]; then
  if jq -e '.hooks.SessionStart[]?.hooks[]? | select(.command | contains("auto-skills"))' "$SETTINGS" >/dev/null 2>&1; then
    echo "Hook already registered in settings.json (skipped)"
  else
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
