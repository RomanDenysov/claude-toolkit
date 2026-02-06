# auto-skills

Context-aware skill and plugin loader for Claude Code.

## Problem

Claude Code loads **all** installed skills into the agent's context on every session. If you have skills for Expo, Turborepo, Next.js, Playwright, and Swift — they all get injected even when you're working on a plain Node.js API. This wastes context and adds noise.

## Solution

A `SessionStart` hook that scans your project for signals (config files, `package.json` deps) and symlinks **only matching skills** into each project's `.claude/skills/` directory. Zero noise, zero manual config per project.

### Before

```
Every session loads: turborepo, building-native-ui, update-docs,
vercel-react-best-practices, agent-browser, find-skills
```

### After (Next.js project)

```
Only loads: update-docs, vercel-react-best-practices, find-skills
```

## How It Works

1. On session start, `auto-skills.sh` reads detection rules from `~/.claude/auto-skills.json`
2. Checks the project root for file patterns and `package.json` dependencies
3. Symlinks only matched skills into `<project>/.claude/skills/`
4. Optionally enables matched plugins in `<project>/.claude/settings.json`

```
~/.claude/auto-skills.json     # Detection rules
~/.claude/hooks/auto-skills.sh # The hook
~/.agents/skills/              # Your skills library (all available skills)
<project>/.claude/skills/      # Auto-generated symlinks (per-project)
```

## Install

```bash
cd claude-toolkit
./auto-skills/install.sh
```

Then edit `~/.claude/auto-skills.json`:
- Set `skills_library` to your skills directory (e.g., `~/.agents/skills` or wherever your skills live)
- Add/modify detection rules

## Configuration

Edit `~/.claude/auto-skills.json`:

```json
{
  "skills_library": "/Users/you/.agents/skills",
  "rules": [
    {
      "name": "nextjs",
      "detect": {
        "files": ["next.config.ts", "next.config.js"],
        "deps": ["next"]
      },
      "skills": ["update-docs", "vercel-react-best-practices"],
      "plugins": {}
    }
  ],
  "always_enabled": {
    "skills": ["find-skills"],
    "plugins": {}
  }
}
```

### Rule fields

| Field | Description |
|-------|-------------|
| `name` | Human-readable label |
| `detect.files` | File paths or globs to check in project root (any match triggers the rule) |
| `detect.deps` | npm package names to check in `package.json` (any match triggers) |
| `skills` | Skill names to symlink when matched |
| `plugins` | Plugin overrides for project `.claude/settings.json` |

### Built-in rules (example config)

| Signal | Enables |
|--------|---------|
| `turbo.json` | turborepo |
| `expo` in deps / `app.json` | building-native-ui |
| `next` in deps / `next.config.*` | update-docs, vercel-react-best-practices |
| `react` in deps | vercel-react-best-practices |
| `playwright`/`cypress` in deps | agent-browser |
| `Package.swift` / `*.xcodeproj` | swift-lsp plugin |

## How It Stays Clean

- Only manages symlinks pointing to the skills library — your manually created project skills are untouched
- Runs async on session start — no delay
- No Python dependency — pure bash + jq
- Compatible with macOS default bash (v3)

## Manual Hook Setup

If `install.sh` can't modify your settings, add this to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/you/.claude/hooks/auto-skills.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```
