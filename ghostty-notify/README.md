# ghostty-notify

macOS notification + terminal bell when Claude Code stops and waits for your input.

## What It Does

Triggers on the `Stop` hook — every time Claude Code finishes its turn and needs your reaction, you get:

- **macOS notification** — "Claude Code: [project-name] Waiting for your input" with a "Tink" sound
- **Terminal bell** — works in Ghostty, iTerm2, Kitty, Alacritty, and any terminal that supports `\a`

The notification includes the project directory name so you know which session needs attention.

## Install

```bash
cd claude-toolkit
chmod +x ghostty-notify/install.sh
./ghostty-notify/install.sh
```

## Requirements

- `jq` — `brew install jq`
- macOS (uses `osascript` for notifications)

## Manual Setup

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/you/.claude/ghostty-notify.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```

## Customization

Edit `~/.claude/ghostty-notify.sh` to change the notification sound, title, or add additional triggers (e.g., Slack webhook, push notification service).
