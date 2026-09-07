#!/usr/bin/env bash

# Offline integration tests: real Git repositories, mocked GitHub responses.
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$script_dir/stow/home/bin/git-prune-local-branches"
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/git-prune-tests.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT

export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_TERMINAL_PROMPT=0
export REAL_GIT
REAL_GIT=$(command -v git)
export TEST_REMOTE="$sandbox/remote.git"
export GH_CALLS="$sandbox/gh-calls" GIT_CALLS="$sandbox/git-calls"
export GH_RESPONSE="$sandbox/gh-response" GH_FAIL=false GH_FAIL_BATCH=0 FETCH_FAIL=false
export MUTATE_BRANCH="" MUTATE_OID=""
original_path=$PATH
mkdir "$sandbox/bin"

cat > "$sandbox/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$GIT_CALLS"
case $1 in
    fetch)
        [[ "$FETCH_FAIL" == false ]] || exit 1
        # Keep all fetching offline, even when origin has a GitHub URL.
        exec "$REAL_GIT" fetch --prune "$TEST_REMOTE" '+refs/heads/*:refs/remotes/origin/*'
        ;;
    diff|log|patch-id|merge-base)
        echo "Unexpected per-branch history/patch scan: $*" >&2
        exit 99
        ;;
esac
exec "$REAL_GIT" "$@"
EOF

cat > "$sandbox/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >> "$GH_CALLS"
cat "$GH_RESPONSE"
if [[ -n "$MUTATE_BRANCH" ]]; then
    "$REAL_GIT" update-ref "refs/heads/$MUTATE_BRANCH" "$MUTATE_OID"
fi
[[ "$GH_FAIL" == false && $(grep -cx graphql "$GH_CALLS") != "$GH_FAIL_BATCH" ]]
EOF
chmod +x "$sandbox/bin/git" "$sandbox/bin/gh"

fail() {
    printf 'FAIL: %s\n%s\n' "$1" "${output:-}" >&2
    exit 1
}

assert_contains() {
    [[ "$output" == *"$1"* ]] || fail "expected output to contain: $1"
}

assert_absent() {
    [[ "$output" != *"$1"* ]] || fail "unexpected output: $1"
}

assert_no_gh() {
    [[ ! -s "$GH_CALLS" ]] || fail "unexpected GitHub lookup"
}

assert_lookup() {
    local expected_batches=${1:-1} argument
    [[ $(grep -cx graphql "$GH_CALLS") == "$expected_batches" ]] || fail "unexpected number of GraphQL batches"
    for argument in --hostname github.com owner=owner name=repo; do
        grep -Fxq -- "$argument" "$GH_CALLS" || fail "missing gh argument: $argument"
    done
    if grep -Fq -- --paginate "$GH_CALLS"; then fail 'lookup must not scan all PR history'; fi
    grep -Fq 'object(oid:' "$GH_CALLS" || fail 'lookup must target local commit OIDs'
    grep -Fq 'associatedPullRequests(first: 100)' "$GH_CALLS" || fail 'commit PR connections must be bounded'
    grep -Fq 'pageInfo { hasNextPage }' "$GH_CALLS" || fail 'missing completeness check'
    awk '/repository\(owner:/ { if (gsub(/object\(oid:/, "") > 20) exit 1 }' "$GH_CALLS" \
        || fail 'a batch exceeded 20 tips'
}

run_script() {
    : > "$GH_CALLS"
    : > "$GIT_CALLS"
    output=$(PATH="$sandbox/bin:$original_path" bash "$script" "$@" 2>&1)
}

git init -q --bare "$TEST_REMOTE"
git init -q -b main "$sandbox/work"
cd "$sandbox/work"
git remote add origin "$TEST_REMOTE"
printf 'value = "original"\n' > app.py
git add app.py
git commit -qm base
base_oid=$(git rev-parse HEAD)
git branch merged
git tag merged # A short ref would become heads/merged rather than merged.
git branch checked-out
git worktree add -q "$sandbox/linked-worktree" checked-out

git switch -qc squash
printf 'feature\n' > feature.txt
git add feature.txt
git commit -qm feature
pr_head=$(git rev-parse HEAD)
git switch -q main
git merge --squash squash >/dev/null
git commit -qm 'squash merge of feature'

git switch -qc advanced squash
printf 'additional local work\n' >> feature.txt
git commit -qam 'after PR merge'
advanced_oid=$(git rev-parse HEAD)

git switch -qc whitespace "$base_oid"
printf 'value = "a b"\n' > app.py
git commit -qam 'meaningful local whitespace'
git switch -q main
printf 'value = "ab"\n' > app.py
git commit -qam 'different change on main'
git push -q origin main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
printf '%s\t%s\ttrue\tmain\towner/repo\n' "$pr_head" "$pr_head" > "$GH_RESPONSE"

run_script --dry-run
assert_contains "'merged' (merged into origin/main)"
assert_absent "'heads/merged'"
assert_absent "'squash'"
assert_absent "'advanced'"
assert_absent "'whitespace'"
assert_absent "'checked-out'"
assert_absent "'main'"
assert_no_gh
[[ $(grep -c '^for-each-ref --merged=' "$GIT_CALLS") == 1 ]] || fail "expected batched ancestry detection"
echo 'PASS: generic ancestry-only detection, tag collision, worktree protection'

for url in https://github.com/owner/repo.git git@github.com:owner/repo.git ssh://git@github.com/owner/repo.git https://github.com/owner/repo/; do
    git remote set-url origin "$url"
    run_script --dry-run
    assert_contains "'merged' (merged into origin/main)"
    assert_contains "'squash' (merged-PR into origin/main)"
    assert_absent "'advanced'"
    assert_absent "'whitespace'"
    assert_absent "'checked-out'"
    assert_lookup
    git show-ref --verify --quiet refs/heads/squash || fail 'dry-run deleted squash'
done
echo 'PASS: standard GitHub URL forms, exact head matching, bounded commit lookup'

for url in https://gitlab.com/owner/repo.git https://github.com.example.org/owner/repo.git https://example.org/github.com/owner/repo.git git@github-work:owner/repo.git https://github.example.org/owner/repo.git https://github.com/owner/repo/extra; do
    git remote set-url origin "$url"
    run_script --dry-run
    assert_contains "'merged' (merged into origin/main)"
    assert_absent "'squash'"
    assert_no_gh
done
echo 'PASS: unknown hosts, misleading URLs, and SSH aliases stay generic'

git remote set-url origin https://github.com/owner/repo.git
GH_FAIL=true
run_script --dry-run
assert_contains 'GitHub PR lookup failed; using ancestry checks only.'
assert_contains "'merged' (merged into origin/main)"
assert_absent "'squash'"
assert_lookup
GH_FAIL=false
echo 'PASS: partial API output is discarded on failure'

: > "$GH_RESPONSE"
run_script --dry-run
assert_contains "'merged' (merged into origin/main)"
assert_absent "'squash'"
assert_lookup
echo 'PASS: empty PR results do not authorize deletion'

run_script --dry-run --no-github
assert_contains "'merged' (merged into origin/main)"
assert_absent "'squash'"
assert_no_gh
echo 'PASS: --no-github explicitly skips API lookups'

# Supply only the commands used by the script, deliberately excluding gh.
mkdir "$sandbox/no-gh"
for utility in bash dirname basename mktemp rm awk grep; do
    ln -s "$(command -v "$utility")" "$sandbox/no-gh/$utility"
done
ln -s "$sandbox/bin/git" "$sandbox/no-gh/git"
: > "$GH_CALLS"
output=$(PATH="$sandbox/no-gh" bash "$script" --dry-run 2>&1)
assert_contains 'gh not found; using ancestry checks only.'
assert_contains "'merged' (merged into origin/main)"
assert_absent "'squash'"
assert_no_gh
echo 'PASS: missing gh falls back to ancestry'

FETCH_FAIL=true
if run_script --yes; then
    fail 'fetch failure should be fatal'
fi
assert_contains "failed to fetch 'origin'"
assert_no_gh
git show-ref --verify --quiet refs/heads/merged || fail 'fetch failure deleted a branch'
FETCH_FAIL=false
echo 'PASS: fetch failure prevents lookup and deletion'

# The base branch must remain protected even when it is not checked out.
git switch -q advanced
printf '%s\t%s\ttrue\tmain\towner/repo\n' "$pr_head" "$pr_head" > "$GH_RESPONSE"
run_script --dry-run main
assert_absent "'main'"
assert_absent "'advanced'"
assert_absent "'checked-out'"
git switch -q main
echo 'PASS: base and current branches remain protected'

git push -q "$TEST_REMOTE" main:refs/heads/release/stable
run_script --dry-run release/stable
assert_absent "'squash'"
printf '%s\t%s\ttrue\trelease/stable\towner/repo\n' "$pr_head" "$pr_head" > "$GH_RESPONSE"
run_script --dry-run release/stable
assert_contains "'squash' (merged-PR into origin/release/stable)"
assert_lookup
echo 'PASS: PRs must match the requested base branch'

for record in \
    "$pr_head $pr_head false main owner/repo" \
    "$pr_head $pr_head true other-base owner/repo" \
    "$pr_head $pr_head true main other/repo" \
    "$pr_head $advanced_oid true main owner/repo" \
    "incomplete $pr_head"; do
    printf '%s\n' "$record" > "$GH_RESPONSE"
    run_script --dry-run
    assert_absent "'squash'"
    assert_absent "'advanced'"
done
assert_contains 'some commit PR lists were incomplete'
echo 'PASS: unmerged, wrong-base, wrong-repository, non-head, and incomplete associations are rejected'

printf '%s\t%s\ttrue\tmain\towner/repo\n' "$pr_head" "$pr_head" > "$GH_RESPONSE"
for ((i=0; i<41; i++)); do
    oid=$(printf 'unique local tip %s\n' "$i" | git commit-tree 'HEAD^{tree}' -p "$base_oid")
    git branch "batch-$i" "$oid"
    if [[ "$i" -eq 36 ]]; then
        run_script --dry-run
        assert_lookup 2 # 37 new tips + 3 existing tips: no empty third request.
        assert_contains 'batch 2/2'
    fi
done
git branch duplicate-tip "$pr_head"
run_script --dry-run
assert_lookup 3
assert_contains 'batch 1/3'
assert_contains 'batch 3/3'
assert_contains "'squash' (merged-PR into origin/main)"
[[ $(grep -o 'object(oid:' "$GH_CALLS" | wc -l | tr -d ' ') == 44 ]] || fail 'lookup should deduplicate tips'
GH_FAIL_BATCH=2
run_script --dry-run
assert_lookup 2
assert_contains 'GitHub PR lookup failed; using ancestry checks only.'
assert_contains "'merged' (merged into origin/main)"
assert_absent "'squash'"
assert_absent "'duplicate-tip'"
GH_FAIL_BATCH=0
git branch -D duplicate-tip >/dev/null
for ((i=0; i<41; i++)); do git branch -D "batch-$i" >/dev/null; done
echo 'PASS: request count scales with unique local tips, batches are bounded, late failures discard results'

# Simulate a branch advancing during the API request after refs were inspected.
MUTATE_BRANCH=squash MUTATE_OID=$advanced_oid
run_script --yes
assert_contains "'squash' changed since inspection; skipping."
[[ $(git rev-parse refs/heads/squash) == "$advanced_oid" ]] || fail 'advanced branch was deleted'
MUTATE_BRANCH="" MUTATE_OID=""
git branch -f squash "$pr_head" >/dev/null
git branch merged "$base_oid"
run_script --yes
assert_lookup
if git show-ref --verify --quiet refs/heads/merged; then fail 'merged branch was not deleted'; fi
if git show-ref --verify --quiet refs/heads/squash; then fail 'squash branch was not deleted'; fi
for branch in main advanced whitespace checked-out; do
    git show-ref --verify --quiet "refs/heads/$branch" || fail "protected/unmerged branch deleted: $branch"
done
echo 'PASS: changed-tip guard and actual deletion of verified candidates'

# With no eligible unmerged branches there is no need to contact GitHub.
git branch -D advanced whitespace >/dev/null
run_script --dry-run
assert_no_gh
echo 'PASS: no PR lookup when ancestry leaves no candidates'

git switch -q --detach main
git worktree remove "$sandbox/linked-worktree"
git branch -D main checked-out >/dev/null
git branch squash "$pr_head"
run_script --dry-run
assert_contains "'squash' (merged-PR into origin/main)"
assert_lookup
echo 'PASS: PR matching works with an empty ancestry result and no local main'

echo 'All git-prune-local-branches integration tests passed.'
