#!/usr/bin/env bash
# install.sh — install to-obsidian-claude into your local Claude Code user config.
#
# Installs into ~/.claude/ (user scope) so the agent + skill are available in every repo,
# regardless of cwd. Idempotent: re-running overwrites files in place.
#
# Usage:
#   ./install.sh                  # install agent + skill + script
#   ./install.sh --uninstall      # remove what this script installed
#   ./install.sh --dry-run        # show what would be installed, don't write
set -euo pipefail

UNINSTALL=0; DRYRUN=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1;;
    --dry-run)   DRYRUN=1;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown arg: $arg" >&2; exit 2;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
AGENT_SRC="$REPO_ROOT/agents/obsidian-publisher.md"
SKILL_SRC="$REPO_ROOT/skills/to-obsidian"
SCRIPT_SRC="$REPO_ROOT/scripts/publish-obsidian.sh"

AGENT_DST="$CLAUDE_DIR/agents/obsidian-publisher.md"
SKILL_DST="$CLAUDE_DIR/skills/to-obsidian"
SCRIPT_DST="$CLAUDE_DIR/skills/to-obsidian/scripts/publish-obsidian.sh"

run() { if [[ $DRYRUN -eq 1 ]]; then echo "[dry-run]" "$@"; else "$@"; fi; }

if [[ $UNINSTALL -eq 1 ]]; then
  echo "Uninstalling to-obsidian-claude from $CLAUDE_DIR"
  run rm -f  "$AGENT_DST"
  run rm -rf "$SKILL_DST"
  echo "Done. (MCP server registration, if any, is left intact — remove with 'claude mcp remove obsidian -s user' if desired.)"
  exit 0
fi

# Sanity: source files exist?
for f in "$AGENT_SRC" "$SCRIPT_SRC" "$SKILL_SRC/SKILL.md" "$SKILL_SRC/SETUP.md"; do
  [[ -e "$f" ]] || { echo "missing source: $f" >&2; exit 3; }
done

echo "Installing to-obsidian-claude → $CLAUDE_DIR"
run mkdir -p "$CLAUDE_DIR/agents" "$CLAUDE_DIR/skills/to-obsidian/scripts"
run cp -f "$AGENT_SRC"          "$AGENT_DST"
run cp -f "$SKILL_SRC/SKILL.md" "$SKILL_DST/SKILL.md"
run cp -f "$SKILL_SRC/SETUP.md" "$SKILL_DST/SETUP.md"
run cp -f "$SCRIPT_SRC"         "$SCRIPT_DST"
run chmod +x "$SCRIPT_DST"

if [[ $DRYRUN -eq 0 ]]; then
  echo ""
  echo "Installed:"
  echo "  $AGENT_DST"
  echo "  $SKILL_DST/SKILL.md"
  echo "  $SKILL_DST/SETUP.md"
  echo "  $SCRIPT_DST"
  echo ""
  echo "Next steps:"
  echo "  1. Restart Claude Code (or start a new session) so it picks up the new agent + skill."
  echo "  2. Try a request like: \"이 PROJECT_MAP.md를 MyVault의 'code-analysis' 노트에 넣어줘\""
  echo "  3. (Optional) For the MCP backend upgrade, see: $SKILL_DST/SETUP.md"
fi
