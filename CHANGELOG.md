# Changelog

## v0.2.0 — 2026-05-28

User-friendly options for diverse open-source usage patterns.

- `--dry-run` — Preview the planned publish (vault/target/mode/source-size/marker presence) without writing.
- `--append` — Append the source to an existing note (or create it) instead of overwriting. Same safety-marker rule applies.
- `--ensure-marker` — Auto-inject `generated-by: to-obsidian` into the source's frontmatter if missing (creates a minimal block if there's none). Default off — preserves the explicit-marker discipline for callers that handle their own frontmatter.
- `OBSIDIAN_DEFAULT_VAULT` — Default vault when `--vault` is omitted. Lets you drop the flag for your primary vault.
- `OBSIDIAN_DEFAULT_FOLDER` — Prefix prepended to `--note` (when the note path isn't absolute). Useful for routing all publishes into e.g. `code-maps/`.
- README now ships in both English (`README.md`) and Korean (`README.ko.md`) with bidirectional language switch.

No breaking changes — every v0.1 invocation continues to work identically.

## v0.1.0 — 2026-05-28

Initial release.

- `obsidian-publisher` subagent (`~/.claude/agents/obsidian-publisher.md`) — delegated publishing
- `to-obsidian` skill (`~/.claude/skills/to-obsidian/`) — inline conversational publishing
- `publish-obsidian.sh` — robust bash backend that resolves vault names via `obsidian.json`, verifies size after write, warns on duplicate note names, and refuses to overwrite foreign content
- One-command installer (`install.sh`)
- Optional Obsidian MCP backend setup guide (Local REST API + WSL mirrored networking)
