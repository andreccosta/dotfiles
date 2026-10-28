# agents

Shared agent skills, linked to `~/.agents/skills` (read by pi and other harnesses that support Agent Skills).

## Claude Code

`./dot install` (or `./dot install agents`) also creates one relative symlink
per shared skill under `~/.claude/skills/`. Claude's discovery root remains a
real directory, so its `synced/` downloads stay separate from the shared skills.

- Edits to existing shared skills are visible through the links immediately.
- Run `./dot install agents` after adding, renaming, or removing a skill to
  create missing links and remove stale links owned by this integration.
- Existing local skills and unrelated symlinks are preserved, with a warning
  on name conflicts. Move a conflicting local entry aside and rerun installation
  if you want the shared version instead.
- The name `synced` is reserved by Claude and is never linked.
- Stow dry runs (`./dot install --simulate agents`) do not change Claude skills.

The sync step refuses to operate if `~/.claude/skills` itself is a symlink.
No startup hook or background synchronization is installed.

## herdr-review

`herdr-review` (the script lives in `stow/home/bin/herdr-review`) asks another coding agent to review your current changes in a new Herdr tab, waits for it, and prints only its findings. Usually you just ask an agent for "a second opinion" and it drives the script through the `herdr-review` skill; you can also run it yourself.

By default it uses a different harness than the caller (codex from claude, claude from anything else) and reviews the diff from the default branch's merge base to the working tree, including uncommitted and untracked files. The reviewer's tab stays open between rounds.

### Review loop

Asking an agent for "a second opinion" runs the whole loop; you don't need to spell out the steps:

1. The reviewer reports numbered findings (F1, F2, ...) and a verdict.
2. The implementing agent checks each finding against the code and decides: fix (with a proposed change), discard (with a reason), or ask you.
3. **Every round, it shows you all findings with those decisions** and waits for your go-ahead before changing code.
4. It applies what you approved and tells the reviewer what was fixed, discarded or deferred, and why (`herdr-review reply`).
5. The reviewer confirms fixes, accepts or disputes each discard, and adds any new findings. Back to step 2, until the reviewer approves or accepts the remaining discards. A discard the agents still disagree on after one counter-argument comes to you as a question.
6. It ends with a summary of what was fixed, what was discarded and why, and the final verdict.

"Fix what you agree with" skips waiting for your go-ahead (you still see every round, and questions are still asked); "just report" stops after the first round. To run it yourself, see `herdr-review --help`.

### Asking an agent

A short request is enough; add a reviewer, model or focus only when you care:

- "Ask for a second opinion."
- "Get a second opinion from codex before I open the PR."
- "Have claude with opus cross-check the migration changes, focusing on locking and rollback safety."
- "Get a second opinion and fix what you agree with." (no waiting for go-ahead)
- "Ask for a second opinion, but just report back." (stops after triage)
- "Second opinion on only what changed since `origin/release-1.2`."
- "Keep waiting for the reviewer." / "Close the reviewer."

In pi, `/skill:herdr-review` forces the skill. Add instructions after it, e.g. `/skill:herdr-review use codex, focus on error handling`.
