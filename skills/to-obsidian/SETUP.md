# to-obsidian — MCP backend setup (one-time)

The skill works **today** with its bash backend (`scripts/publish-obsidian.sh`). The MCP backend
is a strictly-more-robust upgrade because writes go through Obsidian's own process (Local REST
API), which sidesteps the WSL/`/mnt/c`/OneDrive write quirk entirely. It also unlocks tools like
`append`, `patch`, frontmatter edits, and searching.

This setup has three parts. Steps you must do are marked **[YOU]**; steps Claude can do are
marked **[CLAUDE]** (still confirm with the user before running).

## Part 1 — [YOU] Install the Local REST API plugin in your vault

1. Open Obsidian and the target vault (e.g. `MyVault`).
2. **Settings → Community plugins → Browse** → search **"Local REST API"** (by Adam Coddington).
3. **Install**, then **Enable**.
4. Go to the plugin settings:
   - Confirm **"Enable HTTPS server"** is on (default port `27124`, self-signed cert).
   - Click **"Copy API Key"** — paste this somewhere safe; you'll use it in Part 3.
5. (Optional) The HTTPS cert is self-signed; that's fine — our MCP config will set
   `OBSIDIAN_VERIFY_SSL=false`.

## Part 2 — [YOU] Enable WSL mirrored networking (so MCP↔Obsidian can talk)

**Why:** Obsidian listens on Windows `127.0.0.1:27124`. WSL2's default NAT networking can't reach
Windows loopback ports. Mirrored networking shares Windows' network with WSL so `127.0.0.1`
"just works" and stays stable across reboots.

**Requirements:** Windows 11 22H2+ with WSL 2.0+ (you almost certainly have this).

1. In **Windows**, create or edit `C:\Users\<your-windows-user>\.wslconfig`:
   ```ini
   [wsl2]
   networkingMode=mirrored
   ```
2. From a **Windows** terminal (PowerShell/cmd), run:
   ```
   wsl --shutdown
   ```
   Then reopen your WSL session. **All open WSL sessions will close** — save work first.
3. Verify after restart (in WSL):
   ```bash
   cat /etc/wsl.conf 2>/dev/null; ip route show default
   # In mirrored mode, networking behaves like Windows directly.
   ```
4. Test reachability (after the plugin in Part 1 is enabled):
   ```bash
   curl -sk https://127.0.0.1:27124/ | head -5
   # Expect a JSON response from the Local REST API.
   ```

## Part 3 — [YOU runs, secret stays with you] Register the MCP server

The command below uses **user scope** (`-s user`) so it's available in every repo you work in,
regardless of cwd.

Run this in **your** terminal (so your API key isn't echoed into the chat transcript). The `$KEY`
variable keeps the key out of shell history if you `unset KEY` afterward:

```bash
read -rs -p "Paste OBSIDIAN_API_KEY: " KEY; echo
claude mcp add obsidian -s user \
  -e OBSIDIAN_API_KEY="$KEY" \
  -e OBSIDIAN_BASE_URL="https://127.0.0.1:27124" \
  -e OBSIDIAN_VERIFY_SSL=false \
  -- npx -y obsidian-mcp-server@latest
unset KEY
```

Verify it registered:
```bash
claude mcp list
# expect: obsidian   ✓ Connected   (or similar)
```

If the connect check fails: confirm Part 1 (plugin enabled, HTTPS on) and Part 2 (mirrored
networking active), then `claude mcp` will retry on next use.

## Part 4 — [CLAUDE] Use the MCP backend in the skill / subagent

Once registered, both the `to-obsidian` skill and the `obsidian-publisher` subagent should
automatically detect the `obsidian` MCP tools (named `mcp__obsidian__*` or similar) and prefer
them over the bash backend. No edits needed — both already document that preference.

## Removing the MCP server

```bash
claude mcp remove obsidian -s user
```

This leaves the bash backend in place as a working fallback.

## References

- Local REST API plugin: <https://github.com/coddingtonbear/obsidian-local-rest-api>
- MCP server (Node): <https://github.com/cyanheads/obsidian-mcp-server>
- WSL mirrored networking: <https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking>
