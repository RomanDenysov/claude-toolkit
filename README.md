# claude-toolkit

Tools, hooks, and utilities for getting the most out of [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Each tool is independent — install only what you need.

## Tools

### [statusline](./statusline/) — Rich Status Line

```
…/Projects/my-app │  main ✓ │ ◆ opus │ 42%: 52k[▓▓▓▓░░░░░░]72k │ ⏳1/3 │ ⚡2 │ ⏱12m │ $0.45
```

Git branch, model, context window, tasks, MCP servers, duration, cost — all in one line.

### [tmux-usage](./tmux-usage/) — API Usage Bar for tmux

```
4h12m: [▓▓░░░░░░░░] 21% │ 4d0h: [░░░░░░░░░░] 5%
```

5-hour and weekly rate limits with countdown timers. Auto-refreshes expired tokens. 4 built-in themes (Catppuccin, Tokyo Night, Nord, Gruvbox) + custom colors.

### [claude-keychain](./claude-keychain/) — Keychain CLI

```bash
claude-keychain token           # access token
claude-keychain expires         # "3h42m" or "expired"
claude-keychain subscription    # "pro", "max", etc.
```

Read Claude Code OAuth credentials from macOS Keychain. Handles hex-encoded data blobs transparently.

### [ghostty-notify](./ghostty-notify/) — Desktop Notifications

macOS notification + terminal bell when Claude finishes and waits for your input.

### [auto-skills](./auto-skills/) — Context-Aware Skill Loader

Reduces skill index noise by enabling only relevant skills per project.

## Install

```bash
git clone https://github.com/RomanDenysov/claude-toolkit.git
cd claude-toolkit

# Install the tools you want
./statusline/install.sh
./tmux-usage/install.sh
./claude-keychain/install.sh
./ghostty-notify/install.sh
./auto-skills/install.sh
```

Each installer has `--help` for options (themes, modes, etc.).

## Requirements

- macOS
- [jq](https://jqlang.github.io/jq/) — `brew install jq`
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

## License

MIT
