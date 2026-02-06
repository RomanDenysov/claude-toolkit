# claude-toolkit

A collection of tools, hooks, and utilities for getting the most out of [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Tools

| Tool | Description |
|------|-------------|
| [auto-skills](./auto-skills/) | Context-aware skill & plugin loader — only enables relevant skills per project based on tech stack detection |
| [statusline](./statusline/) | Rich status line with Tokyo Night colors — git, model, context usage, tasks, cost |

## Install

Each tool has its own `install.sh`. Clone the repo and run the ones you need:

```bash
git clone https://github.com/RomanDenysov/claude-toolkit.git
cd claude-toolkit

# Install tools
chmod +x auto-skills/install.sh statusline/install.sh
./auto-skills/install.sh
./statusline/install.sh
```

## Requirements

- [jq](https://jqlang.github.io/jq/) — `brew install jq`
- Claude Code with hooks support

## License

MIT
