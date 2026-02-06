#!/bin/bash
# auto-skills.sh — Automatically enable project-relevant skills and plugins
# Runs as a Claude Code SessionStart hook.
#
# Scans the project for signals (config files, package.json deps) and
# symlinks only matching skills into .claude/skills/ for that project.
#
# Compatible with macOS default bash (v3).

set -euo pipefail

CONFIG="$HOME/.claude/auto-skills.json"
PROJECT_ROOT="${PWD}"

# Skip if no config or not in a project
if [ ! -f "$CONFIG" ] || [ "$PROJECT_ROOT" = "$HOME/.claude" ] || [ "$PROJECT_ROOT" = "$HOME" ]; then
  exit 0
fi

# Locate jq — check common paths
JQ=""
for candidate in /opt/homebrew/bin/jq /usr/local/bin/jq /usr/bin/jq; do
  if [ -x "$candidate" ]; then
    JQ="$candidate"
    break
  fi
done
if [ -z "$JQ" ]; then
  JQ=$(which jq 2>/dev/null || true)
fi
if [ -z "$JQ" ]; then
  echo "auto-skills: jq not found, skipping" >&2
  exit 0
fi

SKILLS_LIBRARY=$($JQ -r '.skills_library' "$CONFIG")
PROJECT_CLAUDE_DIR="$PROJECT_ROOT/.claude"
PROJECT_SKILLS_DIR="$PROJECT_CLAUDE_DIR/skills"
PROJECT_SETTINGS="$PROJECT_CLAUDE_DIR/settings.json"
PKG_JSON="$PROJECT_ROOT/package.json"

# Use temp files for collecting results (bash 3 compat)
SKILLS_FILE=$(mktemp)
PLUGINS_FILE=$(mktemp)
trap 'rm -f "$SKILLS_FILE" "$PLUGINS_FILE"' EXIT

# Seed with always-enabled
$JQ -r '.always_enabled.skills[]' "$CONFIG" >> "$SKILLS_FILE" 2>/dev/null || true
$JQ -c '.always_enabled.plugins // {}' "$CONFIG" > "$PLUGINS_FILE" 2>/dev/null || true

# --- Evaluate each rule ---

RULES_COUNT=$($JQ '.rules | length' "$CONFIG")
i=0
while [ "$i" -lt "$RULES_COUNT" ]; do
  MATCHED=false

  # Check file signals
  for f in $($JQ -r ".rules[$i].detect.files // [] | .[]" "$CONFIG"); do
    case "$f" in
      *\**)
        # glob pattern
        ls "$PROJECT_ROOT"/$f >/dev/null 2>&1 && MATCHED=true && break
        ;;
      *)
        [ -e "$PROJECT_ROOT/$f" ] && MATCHED=true && break
        ;;
    esac
  done

  # Check dependency signals (only if not already matched)
  if [ "$MATCHED" = "false" ] && [ -f "$PKG_JSON" ]; then
    for dep in $($JQ -r ".rules[$i].detect.deps // [] | .[]" "$CONFIG"); do
      if $JQ -e --arg d "$dep" \
        '(.dependencies // {} | has($d)) or (.devDependencies // {} | has($d)) or (.peerDependencies // {} | has($d))' \
        "$PKG_JSON" >/dev/null 2>&1; then
        MATCHED=true
        break
      fi
    done
  fi

  if [ "$MATCHED" = "true" ]; then
    $JQ -r ".rules[$i].skills[]" "$CONFIG" >> "$SKILLS_FILE" 2>/dev/null || true
    # Merge plugins
    RULE_PLUGINS=$($JQ -c ".rules[$i].plugins // {}" "$CONFIG")
    if [ "$RULE_PLUGINS" != "{}" ]; then
      CURRENT=$(cat "$PLUGINS_FILE")
      echo "$CURRENT" | $JQ --argjson rp "$RULE_PLUGINS" '. + $rp' > "$PLUGINS_FILE"
    fi
  fi

  i=$((i + 1))
done

# --- Deduplicate skills ---
SKILLS=$(sort -u "$SKILLS_FILE")
PLUGINS=$(cat "$PLUGINS_FILE")

# --- Apply: create project .claude/skills with symlinks ---

mkdir -p "$PROJECT_SKILLS_DIR"

# Remove old auto-managed symlinks (only those pointing to the skills library)
for link in "$PROJECT_SKILLS_DIR"/*; do
  if [ -L "$link" ]; then
    target=$(readlink "$link" 2>/dev/null || true)
    case "$target" in
      *"$SKILLS_LIBRARY"*|*".agents/skills"*)
        rm "$link"
        ;;
    esac
  fi
done

# Create new symlinks for matched skills
for skill in $SKILLS; do
  src="$SKILLS_LIBRARY/$skill"
  dst="$PROJECT_SKILLS_DIR/$skill"
  if [ -d "$src" ] && [ ! -e "$dst" ]; then
    ln -s "$src" "$dst"
  fi
done

# --- Apply: update project .claude/settings.json for plugins ---

if [ "$PLUGINS" != "{}" ]; then
  mkdir -p "$PROJECT_CLAUDE_DIR"
  if [ -f "$PROJECT_SETTINGS" ]; then
    $JQ --argjson plugins "$PLUGINS" '.enabledPlugins = (.enabledPlugins // {}) + $plugins' \
      "$PROJECT_SETTINGS" > "$PROJECT_SETTINGS.tmp" && mv "$PROJECT_SETTINGS.tmp" "$PROJECT_SETTINGS"
  else
    echo "{\"enabledPlugins\": $PLUGINS}" | $JQ '.' > "$PROJECT_SETTINGS"
  fi
fi
