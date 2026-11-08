# agents

Shared skills in `.agents/skills`, linked by Stow to `~/.agents/skills` for pi
and other harnesses that support Agent Skills.

## Claude Code

`./dot install agents` (also included in `./dot install`) links each shared skill
into `~/.claude/skills/`. Existing links reflect edits immediately; rerun after
adding, renaming, or removing skills to refresh links and remove stale ones.

Local skills, unrelated symlinks, and Claude's reserved `synced/` directory are
preserved. Name conflicts produce warnings; move conflicting entries aside to
use the shared version. The discovery root must be a real directory, not a
symlink. Dry runs (`--simulate`) make no changes; there is no background sync.

## Upstream skills

Run Vercel's `skills` CLI from **`stow/agents`**, without `-g`. The CLI installs
into this package's `.agents/skills`; Stow exposes it globally. `--agent pi`
avoids extra harness-specific links; the skills remain shared by all harnesses.

`skills-lock.json` tracks these upstream skills:

| Skill | Upstream source |
| --- | --- |
| `bro` | [dmmulroy/.dotfiles](https://github.com/dmmulroy/.dotfiles/tree/main/home/.agents/skills/bro) |
| `herdr` | [dmmulroy/.dotfiles](https://github.com/dmmulroy/.dotfiles/tree/main/home/.agents/skills/herdr) |
| `gh-stack` | [github/gh-stack](https://github.com/github/gh-stack/tree/main/skills/gh-stack) |
| `show-me` | [humanlayer/skills](https://github.com/humanlayer/skills/tree/main/plugins/show-me/skills/show-me) |
| `thermo-nuclear-code-quality-review` | [cursor/plugins](https://github.com/cursor/plugins/tree/main/cursor-team-kit/skills/thermo-nuclear-code-quality-review) |

Use a temporary shell helper to keep commands short and the CLI version pinned:

```bash
cd stow/agents
skills() { DISABLE_TELEMETRY=1 npx --yes skills@1.7.6 "$@"; }

skills add github/gh-stack --skill gh-stack --agent pi --yes
skills update --project --yes        # all locked skills
skills update herdr --project --yes  # one skill

git diff
cd ../..
./dot install agents                # refresh links after additions/removals/renames
```

Review and commit skill contents and the lock together. Updates replace files,
not merge edits, and run only manually. Keep upstream copies unchanged except
for `show-me`: preserve or reapply its local browser-opening guidance and Codex
invocation policy. Its lock hash represents the upstream baseline.

Edit our own `delegate` and `second-opinion` skills directly with Git, never
through `skills`. Other local or installer-owned skills (including Plannotator
and Rex) are also outside this workflow.

Repository metadata and licenses are excluded from Stow. The retained
[gh-stack MIT notice](licenses/gh-stack.LICENSE) accompanies the initial import
from `bd0a32504f9ae9f795875a9e6bb90ff7408fda08`. Install its CLI separately:
`gh extension install github/gh-stack`.

## second-opinion

Ask an agent for a second opinion to start a review loop:

1. A fresh reviewer reports numbered findings and a verdict.
2. The implementing agent shows you each finding with a proposed fix, discard
   reason, or question, and waits for approval.
3. It applies approved changes and sends the decisions to the same reviewer.
4. Repeat until the reviewer approves or accepts the remaining discards;
   unresolved disagreements come to you.
5. Finish with fixes, discards, and the final verdict.

The default scope is the default branch's merge base through the working tree,
including uncommitted and untracked files. The default reviewer uses a different
harness (codex from claude, claude otherwise). The reviewer starts with only the
scope, focus, and repository context—not the implementing agent's conclusions.
Follow-up rounds reuse that reviewer's conversation.

Examples:

- "Get a second opinion."
- "Have claude with opus review the migration, focusing on locking and rollback."
- "Get a second opinion and fix what you agree with." (no approval pauses)
- "Second opinion on changes since `origin/release-1.2`, just report." (one round)
- "Keep waiting for the reviewer." / "Close the reviewer."

In pi, use `/skill:second-opinion` to force the skill, with optional instructions.
It prefers native subagents and messaging, falling back to Herdr or Rex; the
reviewer's tab/session stays open until you ask to close it. There is no
`second-opinion` shell command. See [the skill](.agents/skills/second-opinion/SKILL.md)
for mechanism selection, recovery, and detailed review rules.
