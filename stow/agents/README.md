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

## gh-stack

The `gh-stack` skill provides GitHub's guidance for stacked branches and pull
requests, including stack design, command reference, and troubleshooting. It is
vendored unchanged from [github/gh-stack](https://github.com/github/gh-stack/tree/main/skills/gh-stack);
the skill's `README.md` records the upstream revision, and its `LICENSE` retains
the upstream MIT notice.

The skill does not install the CLI extension. If needed, install it separately
with `gh extension install github/gh-stack`. Run `./dot install agents` to
refresh skill links after adding it.

## second-opinion

The initial reviewer must start with fresh conversation context, not resume, continue, or fork an existing conversation. Pass only the review scope, focus, and repository context—not the implementing agent's conclusions. Repository instructions still apply. Follow-up rounds deliberately reuse this new reviewer's conversation.

`second-opinion` is a skill for coordinating another coding agent's review, preferring the host's native subagent and messaging facilities when they support the workflow. Herdr and Rex are fallbacks: a background Herdr tab or a separate Rex session keeps the same reviewer available for follow-ups. There is no `second-opinion` shell command; the old `herdr-review` helper is removed.

Mechanism selection matches `delegate`: check native capabilities and follow their guidance, choosing agent creation and messaging together. Independently launched terminals are not automatically reachable through native messaging. If native facilities cannot support the workflow, prefer Herdr when `HERDR_ENV=1`, otherwise Rex when `REX_SESSION` is set and live; without a supported mechanism, report the blocker. The agent saves scope, resource handles/IDs, round state, and delivery status in temporary recovery notes, so a timeout or compaction need not create another reviewer. The direct Rex fallback uses a fresh, fully published findings file for each round plus terminal inspection because it has no Herdr-style agent-status wait. Startup dialogs require the user's attention; they are never auto-approved. Run `./dot install agents` after the skill rename to refresh Claude's links.

By default it uses a different harness than the caller (codex from claude, claude from anything else) and reviews the diff from the default branch's merge base to the working tree, including uncommitted and untracked files. Name a reviewer explicitly when needed. The reviewer's tab/session stays open between rounds and is closed only on request.

### Review loop

Asking an agent for "a second opinion" runs the whole loop; you don't need to spell out the steps:

1. The reviewer reports numbered findings (F1, F2, ...) and a verdict.
2. The implementing agent checks each finding against the code and decides: fix (with a proposed change), discard (with a reason), or ask you.
3. **Every round, it shows you all findings with those decisions** and waits for your go-ahead before changing code.
4. It applies what you approved and tells the same reviewer what was fixed, discarded or deferred, and why, using the selected mechanism's messaging facilities.
5. The reviewer confirms fixes, accepts or disputes each discard, and adds any new findings. Back to step 2, until the reviewer approves or accepts the remaining discards. A discard the agents still disagree on after one counter-argument comes to you as a question.
6. It ends with a summary of what was fixed, what was discarded and why, and the final verdict.

"Fix what you agree with" skips waiting for your go-ahead (you still see every round, and questions are still asked); "just report" stops after the first round. See [the skill](.agents/skills/second-opinion/SKILL.md) for native commands, completion checks, and recovery instructions.

### Asking an agent

A short request is enough; add a reviewer, model or focus only when you care:

- "Ask for a second opinion."
- "Get a second opinion from codex before I open the PR."
- "Have claude with opus cross-check the migration changes, focusing on locking and rollback safety."
- "Get a second opinion and fix what you agree with." (no waiting for go-ahead)
- "Ask for a second opinion, but just report back." (stops after triage)
- "Second opinion on only what changed since `origin/release-1.2`."
- "Keep waiting for the reviewer." / "Close the reviewer."

In pi, `/skill:second-opinion` forces the skill. Add instructions after it, e.g. `/skill:second-opinion use codex, focus on error handling`.
