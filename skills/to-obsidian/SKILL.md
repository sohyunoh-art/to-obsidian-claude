---
name: to-obsidian
description: Publish code-based markdown documentation (e.g. PROJECT_MAP, code analyses) from any repo into the user's Obsidian vault, with frontmatter, repo-link adaptation, dup-note safety, and a robust publish backend that works across WSL/OneDrive vaults. Use whenever the user asks to "put this doc/map/analysis into Obsidian", "publish to <vault>", "옵시디언에 넣어줘", or passes an `obsidian://open?...` URI.
---

# to-obsidian — publish code docs into an Obsidian vault

## When to use

Trigger on requests like:
- "이 문서를 옵시디언에 넣어줘 / 보내줘"
- "publish this to my Obsidian vault"
- Any `obsidian://open?vault=...&file=...` URI in the message
- "이 레포 코드맵 떠서 MyVault에 올려"

## Inputs you need (ask if missing)

1. **Source content** — either an existing markdown file path, or a description of what to generate (e.g. "make a PROJECT_MAP for this repo").
2. **Vault** — name (e.g. `MyVault`) or absolute path. Decode from `obsidian://` URI if provided (URL-decode `vault=` and `file=`).
3. **Note** — note path relative to the vault root, e.g. `code-analysis.md`. Decode from the URI's `file=` param and append `.md` if missing.

## Steps

### 1. Resolve the vault path

If the user gave a vault NAME (not absolute path), read `obsidian.json` to find it:
- Windows host (via WSL): `/mnt/c/Users/*/AppData/Roaming/obsidian/obsidian.json`
- Linux: `~/.config/obsidian/obsidian.json`

`obsidian.json` looks like `{"vaults":{"<id>":{"path":"C:\\Users\\...\\<name>","open":true}}}`. Match on the basename of `path`. Convert Windows path to WSL: `C:\Users\X\Y` → `/mnt/c/Users/X/Y` (drive letter lowercased, backslashes flipped).

The `publish-obsidian.sh` script does this resolution automatically — you can just pass `--vault <name>`.

### 2. Generate or load the source content

- If the user pointed to an existing markdown file: use it as-is for adaptation.
- If they asked you to generate (e.g. "code map this repo"): write the doc to the repo (e.g. `PROJECT_MAP.md`) using your normal documentation reasoning, with all factual claims verified against the actual code. Then use that file as the source.

### 3. Adapt for Obsidian

Make these mechanical changes on a COPY of the source (do not mutate the repo file unless that was the user's request):

- **Add YAML frontmatter at the top** with the marker `generated-by: to-obsidian` (the publisher refuses to overwrite without `--force` if this marker is absent):
  ```yaml
  ---
  title: <human title>
  source: <repo name or absolute path>
  generated: <YYYY-MM-DD>
  generated-by: to-obsidian
  tags:
    - <repo-or-domain tag>
    - code-map
  ---
  ```
- **De-link repo-relative markdown links** (`[text](./file.md)` → `` `file.md` ``) — those paths don't resolve in the vault and would be dead links.
- **Leave Obsidian wikilinks `[[…]]` alone** if present.
- **Keep headings/tables/code blocks intact** — the publisher verifies byte parity, so don't reformat needlessly.

Write the adapted content to a temp file, e.g. `/tmp/to-obsidian-<timestamp>.md`.

### 4. Publish — pick the backend

**Prefer the MCP backend if available.** Check whether MCP tools named like `mcp__*__obsidian_*` are present (e.g. `obsidian_create_or_update_file`, `obsidian_append_to_file`, or whatever the registered Obsidian MCP exposes). If so:
- Use the MCP tool to write the note. Pass the adapted content. The MCP server writes through Obsidian's Local REST API, which bypasses the OneDrive/9p fs quirk entirely.

**Fallback: the bash backend.** Run:
```bash
~/.claude/skills/to-obsidian/scripts/publish-obsidian.sh \
  --vault "<vault-name-or-path>" \
  --note  "<relative/note.md>" \
  --source "/tmp/to-obsidian-<timestamp>.md"
```
The script:
- Resolves vault name via `obsidian.json` if not an absolute path.
- Refuses to overwrite notes without the `generated-by: to-obsidian` marker unless `--force`.
- Warns if other notes in the vault share the same basename (Obsidian URI ambiguity).
- Writes via `cp` + size-verification with one retry (defeats the `/mnt/c` + OneDrive misplacement bug).

**Useful options (v0.2+):**
- `--dry-run` — when the user asks "어디로 가는지 미리 보여줘" / "preview only", pass this. The script prints target/mode/marker without writing.
- `--append` — when the user wants to extend an existing daily log / running note rather than overwrite it ("이어쓰기", "append", "add to").
- `--ensure-marker` — when the user-provided source markdown has no frontmatter and they don't want you to adapt it manually. The script auto-injects the safety marker.
- `OBSIDIAN_DEFAULT_VAULT`, `OBSIDIAN_DEFAULT_FOLDER` (env vars) — if either is set in the user's shell, the script auto-fills. Do NOT override an explicit user-provided `--vault` / `--note`; only honor the env vars when the user omitted them.

### 5. Verify and report

After publishing (either backend):
- Confirm the target file size matches the source (byte count).
- Confirm exactly one note with that basename exists in the vault (else mention the dup).
- Confirm no broken repo-relative links remain (`grep -c ']\(\./'` on the published file).
- Report the absolute target path and byte size.

If Obsidian is already open, mention that the user may need to close/reopen the note (or wait for sync) to see external changes — Obsidian doesn't always live-reload externally-modified files.

## Notes & lessons baked in

- **Don't use the editor/agent Write tool to write into `/mnt/c/.../OneDrive/...`** — it has misplaced files into wrong subfolders. Use the bash script (or MCP).
- **`obsidian://open?file=<name>` resolves by basename across the whole vault.** If two notes share that name, the URI is ambiguous. The publisher warns; if you created the duplicate accidentally, remove it.
- **The `generated-by: to-obsidian` frontmatter marker** is the safety latch — it tells the publisher "yes, I created this before, safe to overwrite". Always include it.
- **Vault path lookup must be dynamic** (read `obsidian.json`); paths can differ per machine/Windows user. The script handles this.

## Setup for the MCP backend (one-time)

See `SETUP.md` in this skill's folder. Summary:
1. Install the Obsidian community plugin **Local REST API** (v4.0.0+) in the target vault, copy the API key.
2. Switch WSL to **mirrored networking** so the MCP server (in WSL) can reach Obsidian's `127.0.0.1` (Windows). One-time `.wslconfig` edit + `wsl --shutdown`.
3. Register the MCP server: `claude mcp add obsidian -s user -e OBSIDIAN_API_KEY=… -e OBSIDIAN_BASE_URL=https://127.0.0.1:27124 -e OBSIDIAN_VERIFY_SSL=false -- npx -y obsidian-mcp-server@latest`

Until that's done, the bash backend handles publishing correctly.
