#!/usr/bin/env bash
# publish-obsidian.sh — Publish a markdown file into an Obsidian vault note, reliably.
#
# Why this exists: writing into a OneDrive-synced vault over WSL's /mnt/c (9p + Files-On-Demand)
# is flaky with editor/agent file tools — files can land in the wrong folder. Plain bash `cp`
# works, so this script does the write via cp and then VERIFIES the result (size match), retrying
# once. It also warns about duplicate note names (Obsidian resolves obsidian:// URIs by basename).
#
# This is the fallback backend for the `to-obsidian` skill / `obsidian-publisher` subagent.
# When the Obsidian MCP server is registered (see SETUP.md), the skill/agent should prefer
# the MCP tools instead and skip this script.
#
# Usage:
#   publish-obsidian.sh --vault <name|abs-path> --note <relative/note.md> --source <file.md> [opts]
#
# Required:
#   --vault   Obsidian vault NAME (resolved via obsidian.json) or an absolute vault path.
#             Falls back to $OBSIDIAN_DEFAULT_VAULT if not given.
#   --note    Note path relative to the vault root, e.g. "code-analysis.md".
#             If $OBSIDIAN_DEFAULT_FOLDER is set and the value isn't absolute, the folder is
#             prepended (e.g. note "x.md" + DEFAULT_FOLDER "code-maps" → "code-maps/x.md").
#   --source  Markdown file whose content becomes the note (or appended to it; see --append).
#
# Options:
#   --force            Overwrite a note that lacks the `generated-by: to-obsidian` marker
#   --append           Append source to the target instead of overwriting (creates it if absent)
#   --ensure-marker    Auto-inject `generated-by: to-obsidian` into source frontmatter
#                      (creates a frontmatter block if none exists). Default: off.
#   --dry-run          Run all checks and report what would happen, but don't write.
#   -h, --help         Show this help and exit.
#
# Environment variables:
#   OBSIDIAN_DEFAULT_VAULT    Default vault name/path if --vault not provided.
#   OBSIDIAN_DEFAULT_FOLDER   Default folder prepended to --note (when --note isn't absolute).
#
# Exit codes:
#   0 ok | 2 bad args | 3 vault not resolved | 4 refused (foreign content) | 5 write failed
set -euo pipefail

VAULT="${OBSIDIAN_DEFAULT_VAULT:-}"; NOTE=""; SOURCE=""
FORCE=0; APPEND=0; ENSURE_MARKER=0; DRYRUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)          VAULT="${2:-}"; shift 2;;
    --note)           NOTE="${2:-}"; shift 2;;
    --source)         SOURCE="${2:-}"; shift 2;;
    --force)          FORCE=1; shift;;
    --append)         APPEND=1; shift;;
    --ensure-marker)  ENSURE_MARKER=1; shift;;
    --dry-run)        DRYRUN=1; shift;;
    -h|--help)        grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

[[ -n "$VAULT" && -n "$NOTE" && -n "$SOURCE" ]] || {
  echo "missing required args. Need --vault (or \$OBSIDIAN_DEFAULT_VAULT), --note, --source" >&2; exit 2; }
[[ -f "$SOURCE" ]] || { echo "source not found: $SOURCE" >&2; exit 2; }

# Apply OBSIDIAN_DEFAULT_FOLDER prefix when --note isn't absolute and doesn't already include it.
if [[ -n "${OBSIDIAN_DEFAULT_FOLDER:-}" && "$NOTE" != /* ]]; then
  prefix="${OBSIDIAN_DEFAULT_FOLDER%/}"
  case "$NOTE" in
    "$prefix"/*) ;;                 # already starts with prefix
    *)           NOTE="$prefix/${NOTE#/}";;
  esac
fi

# --- resolve vault name -> WSL path via obsidian.json (or accept an absolute path) ---
resolve_vault() {
  local v="$1"
  if [[ "$v" == /* ]]; then printf '%s' "$v"; return 0; fi
  python3 - "$v" <<'PY'
import glob, json, os, re, sys
name = sys.argv[1]
candidates = glob.glob("/mnt/c/Users/*/AppData/Roaming/obsidian/obsidian.json")
candidates += glob.glob("/mnt/*/Users/*/AppData/Roaming/obsidian/obsidian.json")
home_cfg = os.path.expanduser("~/.config/obsidian/obsidian.json")
if os.path.exists(home_cfg):
    candidates.append(home_cfg)
def win_to_wsl(p):
    m = re.match(r'^([A-Za-z]):[\\/](.*)$', p)
    if m:
        return f"/mnt/{m.group(1).lower()}/" + m.group(2).replace('\\', '/')
    return p
for cfg in candidates:
    try:
        d = json.load(open(cfg, encoding='utf-8'))
    except Exception:
        continue
    for info in (d.get('vaults') or {}).values():
        p = info.get('path', '')
        base = os.path.basename(p.replace('\\', '/').rstrip('/'))
        if base == name:
            print(win_to_wsl(p)); sys.exit(0)
sys.exit(3)
PY
}
VAULT_PATH="$(resolve_vault "$VAULT")" || { echo "could not resolve vault '$VAULT' (not an abs path, not found in obsidian.json)" >&2; exit 3; }
[[ -d "$VAULT_PATH" ]] || { echo "resolved vault path does not exist: $VAULT_PATH" >&2; exit 3; }

TARGET="$VAULT_PATH/$NOTE"

# --- --ensure-marker: inject `generated-by: to-obsidian` into source frontmatter if missing ---
if [[ $ENSURE_MARKER -eq 1 ]]; then
  if ! grep -q '^generated-by:[[:space:]]*to-obsidian' "$SOURCE"; then
    TMP_SRC="$(mktemp --suffix=.md)"
    if head -1 "$SOURCE" | grep -q '^---$'; then
      # Existing frontmatter: insert marker before its closing ---
      awk 'NR==1 && /^---$/ {print; in_fm=1; next}
           in_fm && /^---$/ {print "generated-by: to-obsidian"; print; in_fm=0; next}
           {print}' "$SOURCE" > "$TMP_SRC"
    else
      # No frontmatter: prepend a minimal one
      { printf -- "---\ngenerated-by: to-obsidian\n---\n\n"; cat "$SOURCE"; } > "$TMP_SRC"
    fi
    SOURCE="$TMP_SRC"
    trap 'rm -f "$TMP_SRC"' EXIT
  fi
fi

# --- safety: don't clobber content we didn't generate (applies to overwrite AND append) ---
target_existed=0
if [[ -s "$TARGET" ]]; then
  target_existed=1
  if [[ $FORCE -eq 0 ]] && ! grep -q '^generated-by:[[:space:]]*to-obsidian' "$TARGET" 2>/dev/null; then
    echo "REFUSED: '$TARGET' already has content not generated by this skill." >&2
    echo "         Re-run with --force to overwrite/append, or pick a different --note." >&2
    exit 4
  fi
fi

# --- duplicate note-name warning (Obsidian resolves obsidian:// by basename) ---
base="$(basename "$NOTE")"
dups="$(find "$VAULT_PATH" -name "$base" -not -path "$TARGET" 2>/dev/null || true)"
[[ -n "$dups" ]] && { echo "WARNING: other notes named '$base' exist — obsidian:// URI may be ambiguous:" >&2; echo "$dups" >&2; }

# --- dry-run: report what would happen and exit ---
if [[ $DRYRUN -eq 1 ]]; then
  mode="overwrite"; [[ $APPEND -eq 1 ]] && mode="append"
  echo "DRY-RUN — no write performed."
  echo "  vault:   $VAULT_PATH"
  echo "  target:  $TARGET"
  echo "  exists:  $([[ $target_existed -eq 1 ]] && echo yes || echo no)"
  echo "  mode:    $mode"
  echo "  source:  $SOURCE ($(wc -c <"$SOURCE") bytes)"
  echo "  marker:  $(grep -q '^generated-by:[[:space:]]*to-obsidian' "$SOURCE" && echo present || echo absent)"
  exit 0
fi

# --- write via cp / append + verify (+ one retry) to defeat the /mnt/c OneDrive/9p quirk ---
src_bytes="$(wc -c <"$SOURCE")"
mkdir -p "$(dirname "$TARGET")"

if [[ $APPEND -eq 1 ]]; then
  base_bytes=$([[ $target_existed -eq 1 ]] && wc -c <"$TARGET" || echo 0)
  expected=$(( base_bytes + src_bytes ))
  append_and_verify() {
    cat "$SOURCE" >> "$TARGET" 2>/dev/null || return 1
    sync 2>/dev/null || true
    [[ -f "$TARGET" ]] || return 1
    [[ "$(wc -c <"$TARGET")" -eq "$expected" ]] || return 1
    return 0
  }
  if ! append_and_verify; then
    sleep 1; append_and_verify || { echo "FAILED: append did not grow target as expected: $TARGET" >&2; exit 5; }
  fi
  echo "APPENDED: $TARGET ($base_bytes → $(wc -c <"$TARGET") bytes; +$src_bytes)"
else
  write_and_verify() {
    cp -f "$SOURCE" "$TARGET" 2>/dev/null || return 1
    sync 2>/dev/null || true
    [[ -f "$TARGET" ]] || return 1
    [[ "$(wc -c <"$TARGET")" -eq "$src_bytes" ]] || return 1
    return 0
  }
  if ! write_and_verify; then
    sleep 1; write_and_verify || { echo "FAILED: target missing or size mismatch after write: $TARGET" >&2; exit 5; }
  fi
  echo "PUBLISHED: $TARGET ($(wc -c <"$TARGET") bytes)"
fi
