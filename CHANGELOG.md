# Changelog

## v0.1.0 — 2026-05-28

Initial release.

- `obsidian-publisher` subagent (`~/.claude/agents/obsidian-publisher.md`) — delegated publishing
- `to-obsidian` skill (`~/.claude/skills/to-obsidian/`) — inline conversational publishing
- `publish-obsidian.sh` — robust bash backend that resolves vault names via `obsidian.json`, verifies size after write, warns on duplicate note names, and refuses to overwrite foreign content
- One-command installer (`install.sh`)
- Optional Obsidian MCP backend setup guide (Local REST API + WSL mirrored networking)
