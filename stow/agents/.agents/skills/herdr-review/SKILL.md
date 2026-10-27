---
name: herdr-review
description: "Have another coding agent (different harness or model) review the current changes in a new Herdr tab or worktree and wait for its findings. Use when asked for a second opinion, a review by claude/codex/pi/opencode or another model, or to spawn a reviewer for these changes. Requires HERDR_ENV=1."
---

# Herdr review

Run the `herdr-review` command; do not orchestrate the reviewer with raw `herdr` commands or read its terminal.

```bash
herdr-review [--agent KIND] [--model MODEL] [--worktree] [--base REF] [--focus TEXT] [--timeout SECS]
```

- Defaults: a different harness than yours (codex when you are claude, otherwise claude), the harness's default model, a new tab in the current workspace, and the diff from the default branch's merge base to the working tree, including uncommitted and untracked files.
- Pass `--agent`/`--model` when the user names a reviewer or model. Use `--worktree` only when asked for a worktree or when the reviewer should run checks in isolation; it reviews committed changes only.
- Put user-specific review instructions in `--focus`.
- It blocks until the reviewer finishes, up to `--timeout` (default 540 s). Give your shell tool a timeout longer than that.
- stdout is the reviewer's findings in Markdown. stderr names the reviewer (`review-xxxxxx`) and its tab.

Exit codes:

- `0`: findings printed. Evaluate them against the code before acting; they are another agent's opinion.
- `3`: the reviewer is blocked on an approval or question. Tell the user which tab, and after they answer it run `herdr-review wait <name>`.
- `4`: still working. Run `herdr-review wait <name>` to keep waiting.
- `5`: it finished without writing findings. Tell the user; inspect with `herdr agent read <name> --source recent-unwrapped --lines 120` only if needed.

The reviewer's tab stays open for follow-up. Run `herdr-review cleanup <name>` only when the user asks to close it. `herdr-review --help` has the full reference.
