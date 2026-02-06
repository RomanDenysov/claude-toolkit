# auto-skills

Context-aware skill and plugin loader for Claude Code.

## Problem

Claude Code loads **all** installed skills into the agent's context on every session. If you have skills for Expo, Turborepo, Next.js, Playwright, and Swift — they all get injected even when you're working on a plain Node.js API. This wastes context and adds noise.

## Solution

A `SessionStart` hook that scans your project for signals (config files, `package.json` deps) and symlinks **only matching skills** into each project's `.claude/skills/` directory. Configure detection rules once globally — no per-project setup needed.

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
chmod +x auto-skills/install.sh
./auto-skills/install.sh
```

The installer will:
1. Auto-detect your skills library (`~/.agents/skills`, `~/.claude/skills-library`, etc.)
2. Scan installed skills and generate detection rules automatically
3. Flag any unrecognized skills so you can add custom rules if needed
4. Register the SessionStart hook in `~/.claude/settings.json`

To regenerate the config (e.g., after installing new skills):
```bash
rm ~/.claude/auto-skills.json
./auto-skills/install.sh
```

## Configuration

The config is auto-generated, but you can edit `~/.claude/auto-skills.json` to add custom rules:

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

### Supported auto-detection

The installer recognizes these skills and generates rules automatically:

| Skill pattern | Detection signals |
|---------------|-------------------|
| `turborepo` | `turbo.json` |
| `building-native-ui` | `app.json`, `expo` dep |
| `update-docs` | `next.config.*`, `next` dep |
| `vercel-react-best-practices` | `react` dep |
| `agent-browser` | `playwright.config.*`, `cypress.config.*`, related deps |
| `swift-*`, `ios-*` | `Package.swift`, `*.xcodeproj` |
| `django-*` | `manage.py`, `django` dep |
| `go-*` | `go.mod` |
| `rust-*` | `Cargo.toml` |
| `vue-*` | `vue.config.js`, `vue` dep |
| `angular-*` | `angular.json`, `@angular/core` dep |
| `svelte-*` | `svelte.config.*`, `svelte` dep |
| `tailwind-*` | `tailwind.config.*`, `tailwindcss` dep |
| `prisma-*` | `prisma/schema.prisma`, `@prisma/client` dep |
| `drizzle-*` | `drizzle.config.*`, `drizzle-orm` dep |
| `docker-*` | `Dockerfile`, `docker-compose.yml` |
| `terraform-*` | `main.tf` |

Skills not matching any pattern are flagged during install so you can add custom rules.

### Monorepo support

When a monorepo marker is detected (`turbo.json`, `pnpm-workspace.yaml`, `lerna.json`), the hook also scans `apps/*/` and `packages/*/` for signals — so a Next.js app inside `apps/web/` will still trigger the right skills.

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
