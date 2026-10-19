#!/usr/bin/env bash
# Real linked worktrees with mocked Worktrunk/Paseo; no live daemon changes.
set -euo pipefail
script=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/stow/home/bin/pwt
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/pwt-tests.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT
# macOS /var is a symlink; use physical paths in assertions.
sandbox=$(cd "$sandbox" && pwd -P)
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export ROOT="$sandbox/source checkout" TARGET="$sandbox/source checkout/.worktrees/fix-123"
export CALLS="$sandbox/calls" PROJECTS="$sandbox/projects.json" LIST_FAIL=false CREATE_FAIL=false
mkdir "$sandbox/bin"
git init -q "$ROOT"
git -C "$ROOT" -c user.name=Test -c user.email=test@example.com commit -qm initial --allow-empty
git -C "$ROOT" worktree add -qb fix-123 "$TARGET"
cat > "$sandbox/bin/wt" <<'EOF'
#!/usr/bin/env bash
python3 -c 'import json, os; print(json.dumps({"path": os.environ["TARGET"]}))'
EOF
cat > "$sandbox/bin/paseo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2" in
  'project ls')
    [[ "$LIST_FAIL" == false ]] || exit 1
    cat "$PROJECTS"
    ;;
  'project create')
    [[ "$CREATE_FAIL" == false ]] || exit 1
    [[ "$3" == "$ROOT" && "$4" == --json ]]
    printf 'register\n' >> "$CALLS"
    printf '{"projectId":"prj_new"}\n'
    ;;
  'workspace create') printf '%s\n' "$@" >> "$CALLS" ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$sandbox/bin/"*
export PATH="$sandbox/bin:$PATH" PASEO_BIN_PATH="$sandbox/bin/paseo"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
set_projects() {
  python3 -c 'import json, os; print(json.dumps([
    {"projectId":"prj_wrong", "path":os.environ["TARGET"]},
    {"projectId":"prj_dotfiles", "path":os.environ["ROOT"] + "/."}
  ]))' > "$PROJECTS"
}
assert_open() {
  local project="$1" expected
  expected=$(printf '%s\n' workspace create --isolation local --project "$project" --path "$TARGET")
  [[ "$(< "$CALLS")" == "$expected" ]] || fail 'incorrect workspace arguments'
}
set_projects
# Opening from a linked checkout (including a subdirectory) uses the main project.
mkdir "$TARGET/subdir"
cd "$TARGET/subdir"
for command in 'open' 'open fix-123' 'create feature/foo' 'review 123'; do
  : > "$CALLS"
  read -r -a args <<< "$command"
  bash "$script" "${args[@]}"
  assert_open prj_dotfiles
done
# The main checkout also resolves to the same project.
cd "$ROOT"
: > "$CALLS"
bash "$script" open fix-123
assert_open prj_dotfiles
# An unregistered repository is registered at its source, not its linked checkout.
printf '[]\n' > "$PROJECTS"
: > "$CALLS"
bash "$script" open fix-123
[[ "$(< "$CALLS")" == "$(printf '%s\n' register workspace create --isolation local --project prj_new --path "$TARGET")" ]] \
  || fail 'did not register source checkout'
# Lookup/registration failures must not silently create an unrelated project.
: > "$CALLS"
if LIST_FAIL=true bash "$script" open fix-123 >/dev/null 2>&1; then fail 'ignored lookup failure'; fi
[[ ! -s "$CALLS" ]] || fail 'created workspace after lookup failure'
if CREATE_FAIL=true bash "$script" open fix-123 >/dev/null 2>&1; then fail 'ignored registration failure'; fi
[[ ! -s "$CALLS" ]] || fail 'created workspace after registration failure'
# A submodule's common dir lives under the superproject's .git; use the submodule itself.
export SUPER="$sandbox/super" SUB="$sandbox/super/sub"
git init -q "$SUPER"
git -C "$SUPER" -c protocol.file.allow=always submodule add -q "$ROOT" sub
python3 -c 'import json, os; print(json.dumps([{"projectId":"prj_sub", "path":os.environ["SUB"]}]))' > "$PROJECTS"
cd "$SUB"
: > "$CALLS"
TARGET="$SUB" bash "$script" open
[[ "$(< "$CALLS")" == "$(printf '%s\n' workspace create --isolation local --project prj_sub --path "$SUB")" ]] \
  || fail 'submodule did not resolve to itself'
printf 'pwt tests passed\n'
