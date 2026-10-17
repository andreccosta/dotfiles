#!/usr/bin/env bash

# Real Git repositories, offline fetching, and mocked GitHub metadata.
set -euo pipefail
script=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/stow/home/bin/git-prune-local-branches
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/git-prune-tests.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export REAL_GIT
REAL_GIT=$(command -v git)
export TEST_REMOTE="$sandbox/remote.git" GH_CALLS="$sandbox/gh-calls" GH_RESPONSE="$sandbox/gh-response"
export FETCH_FAIL=false FAIL_BATCH=0 MOVE_TIP=false ADVANCED_OID=""
original_path=$PATH
mkdir "$sandbox/bin"
cat > "$sandbox/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case $1 in
    fetch)
        [[ "$FETCH_FAIL" == false ]] || exit 1
        exec "$REAL_GIT" fetch --prune "$TEST_REMOTE" '+refs/heads/*:refs/remotes/origin/*'
        ;;
    diff|log|patch-id|merge-base) echo "Unexpected per-branch history scan: $*" >&2; exit 99 ;;
esac
exec "$REAL_GIT" "$@"
EOF
cat > "$sandbox/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >> "$GH_CALLS"
filter=""
while [[ $# -gt 0 ]]; do
    if [[ "$1" == --jq ]]; then filter=$2; break; fi
    shift
done
[[ -n "$filter" ]] || { echo 'Missing gh --jq filter' >&2; exit 1; }
jq -r "$filter" "$GH_RESPONSE"
if [[ "$MOVE_TIP" == true ]]; then "$REAL_GIT" update-ref refs/heads/squash "$ADVANCED_OID"; fi
[[ $(grep -cx graphql "$GH_CALLS") != "$FAIL_BATCH" ]]
EOF
chmod +x "$sandbox/bin/git" "$sandbox/bin/gh"

fail() { printf 'FAIL: %s\n%s\n' "$1" "${output:-}" >&2; exit 1; }
run_script() {
    : > "$GH_CALLS"
    output=$(PATH="$sandbox/bin:$original_path" bash "$script" "$@" "$TEST_BASE" 2>&1)
}
assert_candidates() {
    local actual expected
    actual=$(printf '%s\n' "$output" | awk -F "'" '/^Would delete / { print $2 }' | sort)
    expected=$(printf '%s\n' "$@" | sort)
    [[ "$actual" == "$expected" ]] || fail "expected candidates: $*"
}
assert_calls() {
    local count
    count=$(grep -cx graphql "$GH_CALLS" || true)
    [[ "$count" == "$1" ]] || fail "expected $1 GitHub requests, got $count"
}

# Exercise the production jq filter against GraphQL-shaped JSON, not TSV.
set_response() {
    local oid="" head="" merged=false base="" repo="" incomplete=false
    read -r oid head merged base repo <<< "$1"
    if [[ "$oid" == incomplete ]]; then oid=$head; incomplete=true; fi
    jq -n --arg oid "$oid" --arg head "$head" --arg merged "$merged" \
        --arg base "$base" --arg repo "$repo" --arg incomplete "$incomplete" '
        {data: {repository: {tip0:
            (if $oid == "" then null else {
                oid: $oid,
                associatedPullRequests: {
                    nodes: [{headRefOid: $head, merged: ($merged == "true"),
                        baseRefName: $base, baseRepository: {nameWithOwner: $repo}}],
                    pageInfo: {hasNextPage: ($incomplete == "true")}
                }
            } end)
        }}}' > "$GH_RESPONSE"
}

TEST_BASE=main
git init -q --bare "$TEST_REMOTE"
git init -q -b main "$sandbox/work"
cd "$sandbox/work"
git remote add origin "$TEST_REMOTE"
printf 'base\n' > file
git add file; git commit -qm base
base_oid=$(git rev-parse HEAD)
git branch merged; git tag merged # Short refs must not confuse branches and tags.
git worktree add -qb checked-out "$sandbox/worktree"
git switch -qc merge-commit
printf 'merge commit feature\n' > merge-file
git add merge-file; git commit -qm 'merge commit feature'
git switch -q main
git merge -q --no-ff merge-commit -m 'merge feature'
git switch -qc squash
printf 'feature\n' >> file
git commit -qam feature
pr_head=$(git rev-parse HEAD)
git switch -q main
git merge --squash squash >/dev/null; git commit -qm squash
git switch -qc advanced squash
printf 'additional local work\n' >> file
git commit -qam advanced
ADVANCED_OID=$(git rev-parse HEAD)
git switch -q main
git switch -qc rebase "$base_oid"
printf 'rebased feature\n' > rebase-file
git add rebase-file; git commit -qm 'rebased feature'
rebase_head=$(git rev-parse HEAD)
git switch -q main
git cherry-pick "$rebase_head" >/dev/null
[[ $(git rev-parse HEAD) != "$rebase_head" ]] || fail 'rebase fixture must rewrite the tip'
git push -q origin main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
set_response "$pr_head $pr_head true main owner/repo"

# A valid origin/HEAD supplies the base without guessing main/master.
: > "$GH_CALLS"
output=$(PATH="$sandbox/bin:$original_path" bash "$script" --dry-run --no-github 2>&1)
assert_candidates merged merge-commit
[[ "$output" == *'against origin/main'* ]] || fail 'inferred base not reported'
assert_calls 0

# Missing or dangling origin/HEAD requires an explicit base, even with main present.
for state in missing dangling; do
    git symbolic-ref --delete refs/remotes/origin/HEAD
    if [[ "$state" == dangling ]]; then
        git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/missing
    fi
    : > "$GH_CALLS"
    if output=$(PATH="$sandbox/bin:$original_path" bash "$script" --dry-run 2>&1); then
        fail "$state origin/HEAD must require an explicit base"
    fi
    [[ "$output" == *'explicit base branch is required'* ]] || fail 'missing base error'
    assert_calls 0
    run_script --dry-run --no-github
    assert_candidates merged merge-commit
    git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
done

run_script --dry-run --no-github
assert_candidates merged merge-commit
git branch -D merge-commit >/dev/null
git remote set-url origin https://github.com/owner/repo.git
set_response "$rebase_head $rebase_head true main owner/repo"
run_script --dry-run
assert_candidates merged rebase
git branch -D rebase >/dev/null
set_response "$pr_head $pr_head true main owner/repo"
echo 'PASS: origin/HEAD detection, explicit fallback, real merges, and rewritten rebase tips'

for url in "$TEST_REMOTE" https://github.com.example.org/owner/repo.git git@github-work:owner/repo.git; do
    git remote set-url origin "$url"
    run_script --dry-run
    assert_candidates merged
    assert_calls 0
done
for url in https://github.com/owner/repo.git git@github.com:owner/repo.git ssh://git@github.com/owner/repo.git; do
    git remote set-url origin "$url"
    run_script --dry-run
    assert_candidates merged squash
    assert_calls 1
    git show-ref --verify --quiet refs/heads/squash || fail 'dry-run deleted a branch'
done
run_script --dry-run --no-github
assert_candidates merged
assert_calls 0
echo 'PASS: remote detection, ancestry fallback, exact PR tips, and protected branches'

# An explicitly selected non-default base wins over origin/HEAD and main.
git branch release/stable main
git push -q "$TEST_REMOTE" release/stable
TEST_BASE=release/stable
set_response "$pr_head $pr_head true release/stable owner/repo"
run_script --dry-run
assert_candidates merged squash
set_response "$pr_head $pr_head true main owner/repo"
run_script --dry-run
assert_candidates merged
TEST_BASE=does-not-exist
if run_script --dry-run; then fail 'missing remote base must be rejected'; fi
assert_calls 0
TEST_BASE=main
git branch -D release/stable >/dev/null
echo 'PASS: arbitrary explicit base and missing remote base'

# Associated commits, unmerged PRs, other targets, and missing data are not proof.
for record in "" "incomplete $pr_head" \
    "$pr_head $ADVANCED_OID true main owner/repo" \
    "$pr_head $pr_head false main owner/repo" \
    "$pr_head $pr_head true other-base owner/repo" \
    "$pr_head $pr_head true main other/repo"; do
    set_response "$record"
    run_script --dry-run
    assert_candidates merged
done
set_response "$pr_head $pr_head true main owner/repo"
echo 'PASS: ambiguous or incomplete PR metadata keeps branches'

# 51 unique unmerged tips cross the batch boundary; aliases must be deduplicated.
for ((i=0; i<49; i++)); do
    oid=$(printf 'tip %s\n' "$i" | git commit-tree 'HEAD^{tree}' -p "$base_oid")
    git branch "batch-$i" "$oid"
done
git branch duplicate-tip "$pr_head"
run_script --dry-run
assert_candidates merged squash duplicate-tip
assert_calls 2
for argument in --hostname github.com owner=owner name=repo; do
    grep -Fxq -- "$argument" "$GH_CALLS" || fail "missing API argument: $argument"
done
if grep -Fq -- --paginate "$GH_CALLS"; then fail 'must not scan all PR history'; fi
[[ $(grep -o 'object(oid:' "$GH_CALLS" | wc -l | tr -d ' ') == 51 ]] || fail 'tips were not deduplicated'
awk '/repository\(owner:/ { if (gsub(/object\(oid:/, "") > 50) exit 1 }' "$GH_CALLS" || fail 'batch exceeds 50 tips'
FAIL_BATCH=2
run_script --dry-run
assert_calls 2
assert_candidates merged
[[ "$output" == *'GitHub PR lookup failed'* ]] || fail 'API failure was not reported'
FAIL_BATCH=0
for ((i=0; i<49; i++)); do git branch -D "batch-$i" >/dev/null; done
git branch -D duplicate-tip >/dev/null
echo 'PASS: bounded batches, deduplication, and safe fallback after a later batch fails'

FETCH_FAIL=true
if run_script --yes; then fail 'fetch failure must be fatal'; fi
assert_calls 0
git show-ref --verify --quiet refs/heads/merged || fail 'deleted a branch after fetch failure'
FETCH_FAIL=false
MOVE_TIP=true
run_script --yes
[[ "$output" == *'changed since inspection; skipping.'* ]] || fail 'missing changed-tip guard'
[[ $(git rev-parse refs/heads/squash) == "$ADVANCED_OID" ]] || fail 'deleted an advanced branch'
MOVE_TIP=false
git branch -f squash "$pr_head" >/dev/null
git branch merged "$base_oid"
run_script --yes
for branch in merged squash; do
    if git show-ref --verify --quiet "refs/heads/$branch"; then fail "did not delete $branch"; fi
done
for branch in main advanced checked-out; do
    git show-ref --verify --quiet "refs/heads/$branch" || fail "deleted protected/unmerged branch $branch"
done
git branch -D advanced >/dev/null
run_script --dry-run
assert_candidates
assert_calls 0
echo 'PASS: fetch failures, changed tips, actual deletion, and skipping unnecessary API calls'
