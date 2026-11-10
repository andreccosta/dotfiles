---
name: worktrunk
description: "Manage Git worktrees with Worktrunk (wt). Use before creating, switching, configuring hooks for, or removing worktrees, including starting agents in isolated worktrees and sharing local assets safely."
---

# Worktrunk

Use `wt`, not raw `git worktree add/remove`, for worktree lifecycle so configured
paths and hooks apply. Do not create a worktree merely because this skill was
loaded: follow the user's requested checkout/session and repository policy.
Use `wt <command> --help` for flags not covered here; these commands were checked
against wt v0.81.0.

## Inspect, name, create

- Read repository instructions; check `pwd`, `git status --short`, and `wt list`.
  Preserve unrelated changes and reuse an existing worktree when appropriate.
- Follow the user's branch name/prefix and base. Otherwise follow repository
  conventions, or ask if unclear; don't impose `chore/` on every task. Verify
  the base exists and check for branch/path collisions before creation.
- Inspect `wt hook show`, project `.config/wt.toml`, and user
  `~/.config/worktrunk/config.toml` (including overrides) before running hooks.
  Review approval requests rather than routinely adding `--yes` or `--no-hooks`.

```bash
wt switch --create <branch> --base <base> --no-cd
wt switch <existing-branch> --no-cd
wt list --format=json
```

`--create` creates a new branch; without it, the branch must exist (switching may
still create its worktree). Omit `--base` only when the default branch is the
intended base. Use structured list output to obtain the actual worktree path;
require exactly one matching `.items[].branch` and read its `.worktree.path`.
Don't guess paths from sanitized branch names. This dotfiles setup defaults to
`<primary-repo>/.worktrees/<sanitized-branch>`, but project config can override it.

## Agent cwd and sessions

A shell's `wt switch` does **not** relocate an already-running agent's session
cwd. Even a shell `cd` may affect only that one tool invocation.

Start a fresh agent rooted at the resolved worktree path using the host's
supported cwd option, or `wt switch <branch> -x <agent-cli> -- <prompt-args>`.
`--execute` starts its program in the chosen worktree even with `--no-cd`.
For Rex/Herdr or delegation, consult the relevant skill and pass the worktree
path explicitly when creating the session/workspace. Do not infer agent cwd
from a session label or the terminal's current directory.

If continuing the current agent, explicitly scope **all** commands and file edits
to that path: use a tool cwd, absolute paths, `git -C <path>`, `wt -C <path>`, or
`cd <path> && ...` within each shell call. Confirm the path, branch, and status
before editing/testing and again before reporting; never assume a previous
shell switch persisted.

## Hooks and shared local assets

`pre-start` blocks new-worktree setup; `post-start` runs in the background.
Check setup logs/readiness before tests or starting dependent services. Use
`wt config state logs --help` to locate logs. Put dependencies in a single hook
pipeline rather than racing concurrent hooks. Don't blindly rerun a failed hook:
inspect partial state and ensure it is safe/idempotent first.

When writing setup hooks:

- Share only deliberately shared assets (e.g. instructions or skills). Resolve
  an **absolute source path in the primary checkout**; Worktrunk provides
  `{{ primary_worktree_path }}`. Quote shell paths and check the source exists.
- Do not copy a relative symlink verbatim: its target is relative to its new
  parent and can break in nested worktrees. Link to the primary source instead.
- Guard existing real files/directories, then use `ln -sfn "$source" "$dest"`
  only when the destination is absent or a symlink. `-n` avoids following a
  destination directory symlink; never overwrite real local data automatically.
- Keep per-worktree mutable config (notably `.env.local` with DB/port settings)
  as an independent copy, not a shared symlink. Preserve existing local copies.
- Verify links resolve (`test -e`, `readlink`, or a realpath-capable tool), and
  that per-worktree config is not a symlink. Never print secrets while checking.

## Safe cleanup

Remove only when requested or required by an agreed workflow. Check the exact
path's Git status (including untracked files), unmerged/unpushed work, ignored
local data, hooks, and active agents/services first. Leave the target directory
before removal; stop only processes/sessions you own or have approval to stop.

Use `wt remove <branch-or-path> --foreground` to wait for removal; add
`--no-delete-branch` when the branch should be retained. Default removal may
delete an integrated branch. Don't use `rm -rf` as a shortcut. `--force` discards
dirty worktree files; `--force-delete` deletes unmerged branches. Neither is a
routine cleanup flag; get explicit approval for data loss. Don't use `--reap`
without checking which processes it can terminate. Finally verify `wt list`
and report any retained branch or incomplete cleanup.
