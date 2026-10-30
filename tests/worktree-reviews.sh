#!/usr/bin/env bash
# Shared hwt/pwt/rwt contract: real linked checkouts, mocked Worktrunk and UIs.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/worktree-reviews.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT
sandbox=$(cd "$sandbox" && pwd -P)
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export ROOT="$sandbox/source checkout"
export REVIEW="$ROOT/.worktrees/reviews/feature-review"
export NORMAL="$ROOT/.worktrees/feature-normal"
export CALLS="$sandbox/calls" REMOVE_FAIL=0
mkdir "$sandbox/bin"
git init -q "$ROOT"
git -C "$ROOT" -c user.name=Test -c user.email=test@example.com commit -qm initial --allow-empty
git -C "$ROOT" worktree add -qb feature/review "$REVIEW"
git -C "$ROOT" worktree add -qb feature/normal "$NORMAL"
cat > "$sandbox/bin/mock" <<'PY'
#!/usr/bin/env python3
import json, os, sys
name = os.path.basename(sys.argv[0])
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as f:
    f.write(json.dumps([name] + args) + '\n')
if name == 'wt':
    command = args[2]
    if command == 'switch':
        print(json.dumps({'path': os.environ['REVIEW']}))
    elif command == 'list':
        print(json.dumps({'items': [
            {'branch': 'feature/review', 'worktree': {'path': os.environ['REVIEW']}},
            {'branch': 'feature/normal', 'worktree': {'path': os.environ['NORMAL']}}
        ]}))
    elif command == 'remove':
        sys.exit(int(os.environ['REMOVE_FAIL']))
elif name == 'paseo':
    if args[:2] == ['project', 'ls']:
        print(json.dumps([{'path': os.environ['ROOT'], 'projectId': 'project'}]))
    elif args[:2] == ['workspace', 'ls']:
        cwd = os.environ.get('WS_CWD', os.environ['REVIEW'])
        print(json.dumps([{'cwd': cwd, 'workspaceId': 'review-ws'}]))
elif name == 'rex':
    if args[:2] == ['ls', '--json']:
        default = [{'session_id': 'source-session', 'label': 'source checkout'},
                   {'session_id': 'review-session', 'label': 'source checkout/feature/review'}]
        sessions = json.loads(os.environ['REX_SESSIONS']) if 'REX_SESSIONS' in os.environ else default
        print(json.dumps({'sessions': sessions}))
    elif args[0] == 'new':
        print(json.dumps({'session_id': 'new-session'}))
    elif args[0] == 'do':
        sys.exit(int(os.environ.get('SELECT_FAIL', '0')))
PY
chmod +x "$sandbox/bin/mock"
for name in wt herdr paseo rex; do ln -s mock "$sandbox/bin/$name"; done
export PATH="$sandbox/bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=current-ws
export HERDR_BIN_PATH="$sandbox/bin/herdr" PASEO_BIN_PATH="$sandbox/bin/paseo"
export REX_BIN_PATH="$sandbox/bin/rex" REX_SESSION=current-session
assert_call() {
  python3 - "$@" <<'PY'
import json, os, sys
calls = [json.loads(line) for line in open(os.environ['CALLS'])]
assert sys.argv[1:] in calls, (sys.argv[1:], calls)
PY
}
assert_no_ui() {
  python3 - <<'PY'
import json, os
calls = [json.loads(line) for line in open(os.environ['CALLS'])]
assert not any(c[0] in ('herdr', 'rex') or c[:2] == ['paseo', 'workspace'] and c[2] == 'archive' for c in calls), calls
PY
}
for tool in hwt pwt rwt; do
  script="$repo/stow/home/bin/$tool"
  cd "$ROOT"
  for target in 123 pr:123 feature/review "$REVIEW"; do
    : > "$CALLS"
    bash "$script" review "$target"
    expected="$target"
    [[ "$target" != 123 ]] || expected=pr:123
    assert_call wt -C "$ROOT" switch --no-hooks --config-set \
      "worktree-path='{{ repo_path }}/.worktrees/reviews/{{ branch | sanitize }}'" \
      "$expected" --no-cd --format=json
    if [[ "$tool" == hwt ]]; then
      label='review/feature/review'
      [[ "$expected" != pr:123 ]] || label='review/123/feature/review'
      assert_call herdr worktree open --cwd "$ROOT" --path "$REVIEW" --focus --label "$label"
    elif [[ "$tool" == rwt ]]; then
      # An existing session with the worktree's label is reused.
      assert_call rex "do" session.select session_id=review-session
      if grep -q '"rex", "new"' "$CALLS"; then
        printf 'FAIL: created a duplicate Rex session\n' >&2; exit 1
      fi
    else
      assert_call paseo workspace create --isolation local --project project --path "$REVIEW"
    fi
  done
  for target in feature/review "$REVIEW" .worktrees/reviews/feature-review; do
    : > "$CALLS"
    bash "$script" remove "$target"
    assert_call wt -C "$ROOT" remove --foreground --no-hooks --force-delete "$target"
    if [[ "$tool" == hwt ]]; then
      # Removing another checkout must not close the invoking workspace.
      if grep -q '"workspace", "close"' "$CALLS"; then
        printf 'FAIL: closed the invoking workspace when removing another checkout\n' >&2
        exit 1
      fi
    elif [[ "$tool" == rwt ]]; then
      assert_call rex "do" session.select session_id=source-session
      assert_call rex kill review-session
      if grep -q '"kill", "current-session"' "$CALLS"; then
        printf 'FAIL: killed the invoking session when removing another checkout\n' >&2
        exit 1
      fi
    else
      assert_call paseo workspace archive review-ws
    fi
  done
  if [[ "$tool" == hwt ]]; then
    # Normal opens leave Herdr's label alone, even for a review checkout.
    : > "$CALLS"
    bash "$script" switch feature/review
    assert_call herdr worktree open --cwd "$ROOT" --path "$REVIEW" --focus
    if grep -q '"workspace", "rename"' "$CALLS"; then
      printf 'FAIL: renamed a normal workspace\n' >&2; exit 1
    fi
    # Repeated reviews use the same label without parsing Herdr's output.
    : > "$CALLS"
    bash "$script" review pr:123
    assert_call herdr worktree open --cwd "$ROOT" --path "$REVIEW" --focus --label 'review/123/feature/review'
    if grep -q '"workspace", "rename"' "$CALLS"; then
      printf 'FAIL: renamed a workspace separately\n' >&2; exit 1
    fi
    # Detached checkouts use their directory name instead of an empty branch.
    git -C "$REVIEW" checkout -q --detach
    : > "$CALLS"
    bash "$script" review pr:123
    assert_call herdr worktree open --cwd "$ROOT" --path "$REVIEW" --focus --label 'review/123/feature-review'
    git -C "$REVIEW" checkout -q feature/review
  fi
  if [[ "$tool" == rwt ]]; then
    # Without a matching session one is created, and a failed focus only warns.
    : > "$CALLS"
    REX_SESSIONS='[]' SELECT_FAIL=1 bash "$script" review feature/review 2> "$sandbox/stderr"
    assert_call rex new "source checkout/feature/review" --cwd "$REVIEW" --json
    assert_call rex "do" session.select session_id=new-session
    grep -q "enable Remote Control" "$sandbox/stderr"
  fi
  ln -sfn "$ROOT" "$sandbox/link"
  if [[ "$tool" == pwt ]]; then
    # Paseo may report the workspace through a symlinked path.
    : > "$CALLS"
    WS_CWD="$sandbox/link/.worktrees/reviews/feature-review" bash "$script" remove feature/review
    assert_call paseo workspace archive review-ws
  fi
  # Targets given through a symlinked checkout still resolve as review paths.
  link_target="$sandbox/link/.worktrees/reviews/feature-review"
  (cd "$sandbox/link" && : > "$CALLS" && bash "$script" remove "$link_target")
  assert_call wt -C "$ROOT" remove --foreground --no-hooks --force-delete "$link_target"
  [[ "$tool" != pwt ]] || assert_call paseo workspace archive review-ws
  [[ "$tool" != rwt ]] || assert_call rex kill review-session
  # Relative paths resolve from the checkout root, like `wt -C`.
  (cd "$ROOT/.worktrees" && : > "$CALLS" && bash "$script" remove .worktrees/reviews/feature-review)
  assert_call wt -C "$ROOT" remove --foreground --no-hooks --force-delete .worktrees/reviews/feature-review
  # Unresolvable targets warn before falling back to a regular removal.
  : > "$CALLS"
  bash "$script" remove missing 2> "$sandbox/stderr"
  grep -q "could not resolve missing" "$sandbox/stderr"
  assert_call wt -C "$ROOT" remove --foreground missing
  for target in feature/normal "$NORMAL"; do
    : > "$CALLS"
    bash "$script" remove "$target"
    assert_call wt -C "$ROOT" remove --foreground "$target"
  done
  cd "$REVIEW"
  : > "$CALLS"
  bash "$script" remove
  assert_call wt -C "$REVIEW" remove --foreground --no-hooks --force-delete
  if [[ "$tool" == hwt ]]; then
    assert_call herdr workspace close current-ws
  elif [[ "$tool" == rwt ]]; then
    assert_call rex kill review-session
    assert_call rex kill current-session
  else
    assert_call paseo workspace archive review-ws
  fi
  : > "$CALLS"
  if REMOVE_FAIL=1 bash "$script" remove; then
    printf 'FAIL: %s ignored removal failure\n' "$tool" >&2; exit 1
  fi
  assert_no_ui
  cd "$NORMAL"
  : > "$CALLS"
  bash "$script" remove
  assert_call wt -C "$NORMAL" remove --foreground
  cd "$ROOT"
  : > "$CALLS"
  if bash "$script" review >/dev/null 2>&1; then exit 1; fi
  if bash "$script" review one two >/dev/null 2>&1; then exit 1; fi
  [[ ! -s "$CALLS" ]]
done
printf 'worktree review tests passed\n'
