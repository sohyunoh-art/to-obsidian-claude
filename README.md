# to-obsidian-claude

Reliable Claude Code helper for publishing code-based markdown documentation
(PROJECT_MAP, code analyses, architecture notes…) into your **Obsidian vault**.

Ships as **two complementary forms** sharing one robust bash backend:

- 🤖 **`obsidian-publisher` subagent** — delegated publishing. Type once, the subagent
  handles the whole flow without cluttering your main chat. Good for "fire and forget"
  and for running across multiple repos in parallel.
- 🧩 **`to-obsidian` skill** — inline publishing inside an ongoing conversation.
  Good when you're already discussing a doc and just want to land it in Obsidian.

Both go through `publish-obsidian.sh`, which is the actually-robust part.

## Why this exists

Writing into a OneDrive-synced Obsidian vault from WSL is surprisingly fragile.
The default editor/agent file-write tool can **misplace files into unrelated subfolders**
when targeting paths under `/mnt/c/.../OneDrive/...` — the WSL 9p drvfs cache plus the
OneDrive Files-On-Demand virtualization layer behave non-deterministically. The bug
silently breaks "just put this doc in my vault" workflows.

This tool sidesteps that by:

1. Using plain bash `cp` (which works reliably) and **verifying byte parity** after the
   write, with a one-shot retry.
2. Resolving the vault path **dynamically** from Obsidian's `obsidian.json` so you can
   refer to vaults by name and the tool works across machines / Windows user names.
3. Refusing to overwrite notes you didn't create (via a `generated-by: to-obsidian`
   frontmatter marker) — unless you explicitly pass `--force`.
4. **Warning on duplicate note basenames** — Obsidian's `obsidian://open?file=…` URI
   resolves by basename across the whole vault, so duplicates make the URI ambiguous.

If you'd rather write **through Obsidian itself** (most robust — full sidestep of the fs
bug), there's an optional **MCP backend** using the [Local REST API plugin](https://github.com/coddingtonbear/obsidian-local-rest-api)
+ [obsidian-mcp-server](https://github.com/cyanheads/obsidian-mcp-server). See
[`skills/to-obsidian/SETUP.md`](skills/to-obsidian/SETUP.md). The skill / subagent auto-detect
the MCP and prefer it when available.

## Features

- ✅ Works **today** with zero external setup (bash backend, no MCP needed)
- ✅ One-line install (`./install.sh`)
- ✅ Vault resolved by **name**, dynamically (cross-machine)
- ✅ YAML frontmatter with re-publish safety marker
- ✅ Repo-relative markdown links auto-converted (no dead links in vault)
- ✅ Refuses to clobber notes you wrote by hand
- ✅ Duplicate-note warning (preserves `obsidian://` URI determinism)
- ✅ Available as a **skill** and as a **subagent** — pick the form you prefer
- 🧰 Optional MCP backend for bullet-proof publishing through Obsidian itself

## Install

```bash
git clone https://github.com/<you>/to-obsidian-claude.git
cd to-obsidian-claude
./install.sh
```

Then restart Claude Code (or start a new session) so it picks up the new agent + skill.

To remove later: `./install.sh --uninstall`.

### Requirements

- [Claude Code](https://claude.com/claude-code)
- bash, `python3` (for vault-name resolution via `obsidian.json`)
- An Obsidian vault — name and path don't matter; the tool reads `obsidian.json`
- (Optional MCP upgrade) Node.js + npm, the **Local REST API** Obsidian plugin, and
  WSL with mirrored networking — see `SETUP.md`

## Usage

After installing, in any Claude Code session:

**Subagent (delegated):**
> "이 PROJECT_MAP.md를 MyVault의 'code-analysis' 노트에 넣어줘"
>
> Or paste an `obsidian://open?vault=MyVault&file=...` URI.

Claude detects the obsidian-publisher description and delegates. The subagent runs in its
own context, calls the bash script (or MCP if registered), and reports back.

**Skill (inline):**
> "이 문서 옵시디언에 publish해줘 (vault=MyVault, note=architecture.md)"

The main session executes the skill steps inline, keeping you in the conversation.

**Direct script usage (no Claude needed):**
```bash
~/.claude/skills/to-obsidian/scripts/publish-obsidian.sh \
  --vault "MyVault" \
  --note  "code-analysis.md" \
  --source "/path/to/your-doc.md"
```

## Layout

```
to-obsidian-claude/
├── agents/obsidian-publisher.md   → installs to ~/.claude/agents/
├── skills/to-obsidian/
│   ├── SKILL.md                   → installs to ~/.claude/skills/to-obsidian/
│   └── SETUP.md                   (MCP backend setup, optional)
├── scripts/publish-obsidian.sh    → installs to ~/.claude/skills/to-obsidian/scripts/
├── install.sh
├── LICENSE   (MIT)
├── CHANGELOG.md
└── README.md
```

## Background: the WSL+OneDrive bug

If you're curious, the failure mode is: write a file via the default editor tool to an
absolute path like `/mnt/c/Users/<you>/OneDrive/Documents/<vault>/<note>.md`, and the file
materialises inside a nested subfolder you never named — typically replacing the target's
pre-existing placeholder. `readlink` shows no symlink. The pre-existing root file vanishes.
Re-trying with plain bash `cp` to the same path works correctly.

The root cause appears to be the interaction between WSL2's 9p drvfs (with `cache=0x5`) and
OneDrive Files-On-Demand's reparse-point / dehydration logic. This tool's bash backend
sidesteps it entirely by using `cp` + post-write size verification + retry.

## Contributing

Issues and PRs welcome. The tool is intentionally minimal — most of the value is in the
small set of correctness invariants encoded in `publish-obsidian.sh`. If you hit a new
failure mode, please report it with a minimal reproducer.

## License

MIT — see [LICENSE](LICENSE).
