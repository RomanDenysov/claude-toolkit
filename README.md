# claude-toolkit

A collection of tools, hooks, and utilities for getting the most out of [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Tools

| Tool | Description |
|------|-------------|
| [auto-skills](./auto-skills/) | Context-aware skill & plugin loader — only enables relevant skills per project based on tech stack detection |

## Install

Each tool has its own `install.sh`. Clone the repo and run the one you need:

```bash
git clone https://github.com/RomanDenysov/claude-toolkit.git
cd claude-toolkit

# Install a specific tool
chmod +x auto-skills/install.sh
./auto-skills/install.sh
```

## Requirements

- [jq](https://jqlang.github.io/jq/) — `brew install jq`
- Claude Code with hooks support

## License

MIT
