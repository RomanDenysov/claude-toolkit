# tmux-usage

Claude API rate limit usage bar for tmux status line.

```
4h12m: [▓░░░░░░░░░] 10% │ 3d8h: [░░░░░░░░░░] 4%
```

## What It Shows

| Section | Description |
|---------|-------------|
| `4h12m:` | Time until 5-hour rate limit resets |
| `[▓░░░░░░░░░] 10%` | 5-hour utilization with progress bar |
| `3d8h:` | Time until weekly rate limit resets |
| `[░░░░░░░░░░] 4%` | Weekly utilization with progress bar |

Progress bars change color dynamically: green → yellow (>60%) → red (>80%).

### Special States

| Display | Meaning |
|---------|---------|
| `∞ Max` | Max subscription with no rate limits |
| `⚠ Auth` | Token expired and auto-refresh failed — run `/login` in Claude Code |

## How It Works

1. Reads OAuth credentials from macOS Keychain
2. Calls `api.anthropic.com/api/oauth/usage` to fetch utilization
3. Caches responses for 60s to avoid API spam
4. Falls back to cached data when token expires or API is unreachable
5. Token refresh is handled by Claude Code itself - run `/login` if needed

### Keychain Hex Decoding

macOS Keychain stores Claude Code credentials as data blobs, returning hex-encoded strings via `security -w`. The included `claude-keychain.sh` helper transparently detects and decodes this.

## Install

```bash
cd claude-toolkit
chmod +x tmux-usage/install.sh
./tmux-usage/install.sh
```

### Options

```bash
# Choose a color theme
./tmux-usage/install.sh --theme tokyo-night

# Show only 5-hour limit
./tmux-usage/install.sh --mode 5h

# Skip tmux.conf modification (manual setup)
./tmux-usage/install.sh --no-tmux-conf
```

## Themes

| Theme | Description |
|-------|-------------|
| `catppuccin-mocha` | Default — warm pastels on dark background |
| `tokyo-night` | Cool blue-purple tones |
| `nord` | Arctic, north-bluish palette |
| `gruvbox` | Retro warm tones |

### Custom Colors

Set environment variables before the script runs:

```bash
# In tmux.conf — fully custom colors
set -ga status-right " #(CLAUDE_TMUX_BG='#1a1a2e' CLAUDE_TMUX_RED='#e74c3c' CLAUDE_TMUX_GREEN='#2ecc71' CLAUDE_TMUX_YELLOW='#f39c12' CLAUDE_TMUX_GRAY='#636e72' CLAUDE_TMUX_FG='#dfe6e9' ~/.config/tmux/scripts/claude-usage.sh)"
```

## Manual Setup

Add to your tmux config (`~/.config/tmux/tmux.conf` or `~/.tmux.conf`):

```bash
# With default theme
set -ga status-right " #(~/.config/tmux/scripts/claude-usage.sh)"

# With specific theme
set -ga status-right " #(CLAUDE_TMUX_THEME=tokyo-night ~/.config/tmux/scripts/claude-usage.sh)"

# Only weekly limit
set -ga status-right " #(~/.config/tmux/scripts/claude-usage.sh 7d)"
```

Tmux refreshes the status line every 15 seconds by default. The script caches API responses for 60 seconds, so most invocations are instant (~0.2s).

## Requirements

- macOS (uses Keychain and `security` CLI)
- `jq` — `brew install jq`
- `curl`, `xxd` — pre-installed on macOS
- Claude Code with OAuth login (`/login`)
- tmux

## Files

| File | Purpose |
|------|---------|
| `tmux-usage.sh` | Main script — fetches usage, renders bar |
| `claude-keychain.sh` | Helper — reads and decodes Keychain credentials |
| `install.sh` | Installer — copies scripts, updates tmux.conf |
