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

## Upstream skills

Use Vercel's `skills` CLI (plural) from **`stow/agents`**, in project scope.
Stow makes the resulting `.agents/skills` globally available; do not use `-g`
or run installs from the repository root. `skills-lock.json` records only these
upstream-managed skills:

| Skill | Upstream source |
| --- | --- |
| `bro` | [dmmulroy/.dotfiles](https://github.com/dmmulroy/.dotfiles/tree/main/home/.agents/skills/bro) |
| `herdr` | [dmmulroy/.dotfiles](https://github.com/dmmulroy/.dotfiles/tree/main/home/.agents/skills/herdr) |
| `gh-stack` | [github/gh-stack](https://github.com/github/gh-stack/tree/main/skills/gh-stack) |
| `show-me` | [humanlayer/skills](https://github.com/humanlayer/skills/tree/main/plugins/show-me/skills/show-me) |
| `thermo-nuclear-code-quality-review` | [cursor/plugins](https://github.com/cursor/plugins/tree/main/cursor-team-kit/skills/thermo-nuclear-code-quality-review) |

`delegate` and `second-opinion` are our own skills: edit, review, and commit them
directly with Git. They are deliberately absent from the lock and must not be
installed, updated, or restored through `skills`. Other local or installer-owned
skills remain outside this workflow too (including Plannotator and Rex).

```bash
cd stow/agents

# Add a specific upstream skill; Pi's project target is .agents/skills.
DISABLE_TELEMETRY=1 npx --yes skills@1.7.6 add github/gh-stack --skill gh-stack --agent pi --yes

# Update all locked upstream skills, or name just one.
DISABLE_TELEMETRY=1 npx --yes skills@1.7.6 update --project --yes
DISABLE_TELEMETRY=1 npx --yes skills@1.7.6 update herdr --project --yes
git diff

# After adding, renaming, or removing a skill, refresh Claude's links.
cd ../..
./dot install agents
```

Keep managed directories as unchanged upstream copies: updates replace files,
not merge local edits. `show-me` is an existing exception: it retains local
cross-platform browser-opening guidance and a Codex invocation policy. Its lock
hash records the upstream baseline, not those local edits; preserve or reapply
them when updating. Review and commit the skill contents and lock together.
Updates are manual, not part of shell startup or `./dot install`.

Repository-only metadata and licenses are excluded from Stow. The retained
GitHub MIT notice is [licenses/gh-stack.LICENSE](licenses/gh-stack.LICENSE);
the initial import was from commit `bd0a32504f9ae9f795875a9e6bb90ff7408fda08`.
The skill does not install the CLI extension; install it separately with
`gh extension install github/gh-stack` if needed.

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
