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
        print(json.dumps({'path': os.environ['REVIEW'], 'action': os.environ.get('WT_ACTION', 'created')}))
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
        raise AssertionError('rwt must not look up sessions by label')
    elif args[0] == 'new':
        print(json.dumps({'session_id': 'new-session'}))
    elif args[:2] == ['block', 'call']:
        print(json.dumps({'owner': os.environ.get('PANE_OWNER', '')}))
    elif args[0] == 'do' or args[:1] == ['-C']:
        if os.environ.get('SELECT_FAIL', '0') != '0':
            print(os.environ.get('SELECT_ERROR', 'client target default is ambiguous: multiple app clients are connected'), file=sys.stderr)
        sys.exit(int(os.environ.get('SELECT_FAIL', '0')))
PY
chmod +x "$sandbox/bin/mock"
for name in wt herdr paseo rex; do ln -s mock "$sandbox/bin/$name"; done
export PATH="$sandbox/bin:$PATH" HERDR_ENV=1 HERDR_WORKSPACE_ID=current-ws
export HERDR_BIN_PATH="$sandbox/bin/herdr" PASEO_BIN_PATH="$sandbox/bin/paseo"
export REX_BIN_PATH="$sandbox/bin/rex" REX_SESSION=current-session
unset REX_CLIENT REX_BLOCK
assert_call() {
  python3 - "$@" <<'PY'
import json, os, sys
calls = [json.loads(line) for line in open(os.environ['CALLS'])]
assert sys.argv[1:] in calls, (sys.argv[1:], calls)
PY
}
assert_no_rex_open() {
  python3 - <<'PY'
import json, os
calls = [json.loads(line) for line in open(os.environ['CALLS'])]
assert not any(c[0] == 'rex' and c[1] != 'kill' for c in calls), calls
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
      label='source checkout/review/feature/review'
      [[ "$expected" != pr:123 ]] || label='source checkout/review/123/feature/review'
      assert_call rex new "$label" --cwd "$REVIEW" --json
      assert_call rex "do" session.select session_id=new-session
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
      assert_no_ui
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
    # A failed focus only warns; names are never used for lookup.
    : > "$CALLS"
    SELECT_FAIL=1 bash "$script" review feature/review 2> "$sandbox/stderr"
    assert_call rex new "source checkout/review/feature/review" --cwd "$REVIEW" --json
    assert_call rex "do" session.select session_id=new-session
    grep -q 'session source checkout/review/feature/review is ready, but could not be focused' "$sandbox/stderr"
    grep -q 'client target default is ambiguous: multiple app clients are connected' "$sandbox/stderr"
    if grep -q 'enable Remote Control' "$sandbox/stderr"; then
      printf 'FAIL: misdiagnosed focus failure as disabled Remote Control\n' >&2; exit 1
    fi
    # Other failures retain their original diagnostic too.
    SELECT_FAIL=1 SELECT_ERROR='Remote Control is disabled' bash "$script" open feature/review 2> "$sandbox/stderr"
    grep -q 'Remote Control is disabled' "$sandbox/stderr"
    # The invoking pane's owner selects the app, even with multiple apps attached.
    : > "$CALLS"
    REX_BLOCK=current-block PANE_OWNER=owning-client bash "$script" open feature/review
    assert_call rex block call -s current-session -b current-block size
    assert_call rex -C owning-client "do" session.select session_id=new-session
    # Pane ownership takes priority over an inherited client setting.
    : > "$CALLS"
    REX_CLIENT=other-client REX_BLOCK=current-block PANE_OWNER=owning-client bash "$script" open feature/review
    assert_call rex block call -s current-session -b current-block size
    assert_call rex -C owning-client "do" session.select session_id=new-session
    # Missing ownership falls back to Rex's default client selection.
    : > "$CALLS"
    REX_BLOCK=current-block bash "$script" open feature/review
    assert_call rex "do" session.select session_id=new-session
    # Explicit opens always create fresh sessions.
    : > "$CALLS"
    bash "$script" open feature/review
    bash "$script" open feature/review
    assert_call rex new "source checkout/feature/review" --cwd "$REVIEW" --json
    # Detached HEAD uses the directory name, with the requested PR number.
    git -C "$REVIEW" checkout -q --detach
    : > "$CALLS"
    bash "$script" review pr:123
    assert_call rex new "source checkout/review/123/feature-review" --cwd "$REVIEW" --json
    git -C "$REVIEW" checkout -q feature/review
    # Existing worktrees fail with an actionable open command, without Rex calls.
    for action in existing already_at; do
      : > "$CALLS"
      if WT_ACTION="$action" bash "$script" review 123 2> "$sandbox/stderr"; then
        printf 'FAIL: review accepted an existing worktree\n' >&2; exit 1
      fi
      grep -q 'worktree already exists; use `rwt open ' "$sandbox/stderr"
      assert_no_ui
    done
    : > "$CALLS"
    if bash "$script" create feature/review 2> "$sandbox/stderr"; then
      printf 'FAIL: create accepted an existing worktree\n' >&2; exit 1
    fi
    grep -q 'worktree already exists; use `rwt open ' "$sandbox/stderr"
    assert_no_ui
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
  # Relative paths resolve from the checkout root, like `wt -C`.
  (cd "$ROOT/.worktrees" && : > "$CALLS" && bash "$script" remove .worktrees/reviews/feature-review)
  assert_call wt -C "$ROOT" remove --foreground --no-hooks --force-delete .worktrees/reviews/feature-review
  # Unresolvable targets warn before falling back to a regular removal.
  : > "$CALLS"
  bash "$script" remove missing 2> "$sandbox/stderr"
  grep -q "could not resolve missing" "$sandbox/stderr"
  assert_call wt -C "$ROOT" remove --foreground missing
  [[ "$tool" != rwt ]] || assert_no_ui
  for target in feature/normal "$NORMAL"; do
    : > "$CALLS"
    bash "$script" remove "$target"
    assert_call wt -C "$ROOT" remove --foreground "$target"
    [[ "$tool" != rwt ]] || assert_no_ui
  done
  cd "$REVIEW"
  : > "$CALLS"
  bash "$script" remove
  assert_call wt -C "$REVIEW" remove --foreground --no-hooks --force-delete
  if [[ "$tool" == hwt ]]; then
    assert_call herdr workspace close current-ws
  elif [[ "$tool" == rwt ]]; then
    assert_call rex kill current-session
    assert_no_rex_open
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
  if [[ "$tool" == rwt ]]; then
    assert_call rex kill current-session
    assert_no_rex_open
    # Outside a Rex session, removal must not invoke Rex at all.
    : > "$CALLS"
    (unset REX_SESSION; bash "$script" remove)
    assert_no_ui
  fi
  cd "$ROOT"
  : > "$CALLS"
  if bash "$script" review >/dev/null 2>&1; then exit 1; fi
  if bash "$script" review one two >/dev/null 2>&1; then exit 1; fi
  [[ ! -s "$CALLS" ]]
done
printf 'worktree review tests passed\n'
