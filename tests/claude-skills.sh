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
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
FIXTURE="$TMP/repo"
mkdir -p "$HOME" "$FIXTURE/stow/agents/.agents/skills" "$FIXTURE/stow/other"
cp "$REPO_DIR/dot" "$FIXTURE/dot"
SHARED="$FIXTURE/stow/agents/.agents/skills"
CLAUDE="$HOME/.claude/skills"

add_skill() {
  mkdir -p "$SHARED/$1"
  printf '%s\n' '---' "name: $1" 'description: Test skill' '---' > "$SHARED/$1/SKILL.md"
}
install_agents() {
  bash "$FIXTURE/dot" install agents > "$TMP/install.log" 2>&1
}

add_skill alpha
add_skill 'with spaces'
mkdir -p "$SHARED/not-a-skill"
bash "$FIXTURE/dot" install --simulate agents > "$TMP/install.log" 2>&1
require test ! -e "$HOME/.claude"
install_agents
require test "$(readlink "$CLAUDE/alpha")" = '../../.agents/skills/alpha'
require cmp "$CLAUDE/alpha/SKILL.md" "$SHARED/alpha/SKILL.md"
require test -f "$CLAUDE/with spaces/SKILL.md"
require test ! -e "$CLAUDE/not-a-skill"

# Existing links remain unchanged, and edits propagate without another install.
install_agents
printf '\nUpdated instructions\n' >> "$SHARED/alpha/SKILL.md"
require grep -q 'Updated instructions' "$CLAUDE/alpha/SKILL.md"

# Additions, renames, deletions, and directories that cease being skills.
add_skill beta
mv "$SHARED/alpha" "$SHARED/renamed"
rm "$SHARED/with spaces/SKILL.md"
install_agents
require test -f "$CLAUDE/beta/SKILL.md"
require test -f "$CLAUDE/renamed/SKILL.md"
require test ! -L "$CLAUDE/alpha"
require test ! -L "$CLAUDE/with spaces"
rm -r "$SHARED/beta"
# A dry run must not remove stale links or create new ones.
add_skill gamma
bash "$FIXTURE/dot" install --simulate agents > "$TMP/install.log" 2>&1
require test -L "$CLAUDE/beta"
require test ! -L "$CLAUDE/gamma"
install_agents
require test ! -L "$CLAUDE/beta"
require test -f "$CLAUDE/gamma/SKILL.md"

# Local conflicts, unrelated dangling links, and synced data are never replaced.
mkdir -p "$CLAUDE/local" "$CLAUDE/synced"
printf 'keep me\n' > "$CLAUDE/local/SKILL.md"
printf 'downloaded\n' > "$CLAUDE/synced/state"
ln -s missing "$CLAUDE/unrelated"
ln -s missing "$CLAUDE/conflict"
add_skill local
add_skill conflict
add_skill synced
install_agents
require grep -q 'keeping existing Claude skill' "$TMP/install.log"
require grep -q 'skipping reserved Claude skill name' "$TMP/install.log"
require test ! -L "$CLAUDE/local"
require grep -q 'keep me' "$CLAUDE/local/SKILL.md"
require test "$(readlink "$CLAUDE/conflict")" = missing
require test "$(readlink "$CLAUDE/unrelated")" = missing
require grep -q downloaded "$CLAUDE/synced/state"

# Installing another package must not synchronize skills.
add_skill later
bash "$FIXTURE/dot" install other > "$TMP/install.log" 2>&1
require test ! -L "$CLAUDE/later"

# Refuse to write through a symlinked discovery root.
mv "$CLAUDE" "$HOME/saved-skills"
ln -s "$HOME/saved-skills" "$CLAUDE"
install_agents
require grep -q 'not syncing Claude skills' "$TMP/install.log"
require test ! -L "$CLAUDE/later"

printf 'PASS: Claude skill synchronization\n'
