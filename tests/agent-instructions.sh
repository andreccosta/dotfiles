#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
require() {
  if ! "$@"; then
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
  fi
}
command -v stow >/dev/null 2>&1 || { echo 'error: stow is required' >&2; exit 1; }
TMP="$(mktemp -d)"
cleanup() {
  local status=$?
  if [ "$status" -ne 0 ]; then
    for log in "$TMP"/*.log; do
      [ -f "$log" ] || continue
      printf '\n--- %s ---\n' "$(basename "$log")" >&2
      cat "$log" >&2
    done
  fi
  rm -rf "$TMP"
  exit "$status"
}
trap cleanup EXIT
FIXTURE="$TMP/repo"
mkdir -p "$FIXTURE/stow"
cp "$REPO_DIR/dot" "$FIXTURE/dot"
cp -R "$REPO_DIR/stow/agents" "$FIXTURE/stow/agents"
# Keep this fixture small, but use the actual tracked harness links.
for package in pi opencode; do
  case "$package" in
    pi) rel='.pi/agent' ;;
    opencode) rel='.config/opencode' ;;
  esac
  mkdir -p "$FIXTURE/stow/$package/$rel"
  cp -P "$REPO_DIR/stow/$package/$rel/AGENTS.md" "$FIXTURE/stow/$package/$rel/AGENTS.md"
  printf '{}\n' > "$FIXTURE/stow/$package/$rel/settings.json"
done
CANONICAL="$FIXTURE/stow/agents/.agents/AGENTS.md"
ENTRIES=('.claude/CLAUDE.md' '.codex/AGENTS.md' '.pi/agent/AGENTS.md' '.config/opencode/AGENTS.md')

# Both folded directories and pre-existing (unfolded) harness roots must work.
for layout in folded unfolded; do
  export HOME="$TMP/$layout"
  mkdir -p "$HOME"
  if [ "$layout" = unfolded ]; then
    mkdir -p "$HOME/.agents"
    for entry in "${ENTRIES[@]}"; do
      mkdir -p "$HOME/$(dirname "$entry")"
    done
    # Existing deployed OpenCode entry stays valid after its source becomes a link.
    ln -s "$FIXTURE/stow/opencode/.config/opencode/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
    printf 'local Claude instructions\n' > "$HOME/.claude/CLAUDE.md"
  fi
  bash "$FIXTURE/dot" install --simulate agents pi opencode > "$TMP/dry-run.log" 2>&1 || {
    # A conflicting local file is expected to block Stow's simulation.
    require test "$layout" = unfolded
    require grep -q 'existing target' "$TMP/dry-run.log"
  }
  require test ! -e "$HOME/.agents/AGENTS.md"
  if [ "$layout" = unfolded ]; then
    require grep -q 'local Claude instructions' "$HOME/.claude/CLAUDE.md"
  fi
  bash "$FIXTURE/dot" install agents pi opencode > "$TMP/install.log" 2>&1
  require test -f "$HOME/.agents/AGENTS.md"
  for entry in "${ENTRIES[@]}"; do
    require test -L "$HOME/$entry"
    require cmp "$CANONICAL" "$HOME/$entry"
  done
  require test -f "$HOME/.agents/skills/worktrunk/SKILL.md"
  require test -f "$HOME/.claude/skills/worktrunk/SKILL.md"
  if [ "$layout" = unfolded ]; then
    backups=("$HOME/.claude/CLAUDE.md.pre-stow-backup-"*)
    require test "${#backups[@]}" -eq 1
    require grep -q 'local Claude instructions' "${backups[0]}"
  fi
  # Idempotent restow and a canonical edit are reflected by every entry.
  bash "$FIXTURE/dot" install agents pi opencode > "$TMP/install.log" 2>&1
  printf '\nCanonical edit\n' >> "$CANONICAL"
  for entry in "${ENTRIES[@]}"; do
    require grep -q 'Canonical edit' "$HOME/$entry"
  done
  stow --simulate --restow -d "$FIXTURE/stow" -t "$HOME" agents pi opencode > "$TMP/stow.log" 2>&1
done

require grep -q 'Use Worktrunk' "$CANONICAL"
require test "$(grep -Ec '"worktrunk"[[:space:]]*:' "$FIXTURE/stow/agents/skills-lock.json" || true)" -eq 0
printf 'PASS: global agent instructions and Worktrunk skill\n'
