---
name: herdr-review
description: "Get a second opinion from another coding agent (different harness or model) on the current changes, in a new Herdr tab, and iterate with it until both agents agree: triage each round's findings with the user, fix, and send fixes and discards back to the reviewer. Use when asked for a second opinion, a cross-check, a review by claude/codex/pi/opencode or another model, or to have the changes reviewed by another agent. Requires HERDR_ENV=1."
---

# Herdr review

A request like "ask for a second opinion" means the whole loop below, not a single review: every round you triage the reviewer's findings, bring them to the user, fix what they approve, and report back to the reviewer, until you and the reviewer agree. The user does not need to ask for each step.

Use the `herdr-review` command for every step. Do not drive the reviewer with raw `herdr` commands or read its terminal. `herdr-review --help` has the full reference.

```bash
herdr-review [--agent KIND] [--model MODEL] [--base REF] [--focus TEXT] [--timeout SECS]
herdr-review reply <name> <<'EOF'
<response>
EOF
herdr-review wait <name>
herdr-review cleanup <name>
```

- Defaults: a different harness than yours (codex when you are claude, otherwise claude), its default model, a new tab, and the diff from the default branch's merge base to the working tree, including uncommitted and untracked files.
- Pass `--agent`/`--model` when the user names a reviewer or model, and the user's review instructions as `--focus`.
- Each command blocks for up to `--timeout` (default 540 s); give your shell tool a longer timeout. stdout is the reviewer's Markdown; stderr names the reviewer (`review-xxxxxx`) and its tab.

## Review loop

1. **Review.** Run `herdr-review`. Findings are numbered (F1, F2, ...) and end with `VERDICT: approved` or `VERDICT: changes-requested`. If approved with no findings, tell the user and stop.
2. **Triage** every finding, including follow-up rounds' *Not resolved* items, disputed discards, and *New findings*. Check each against the code yourself; it is another agent's opinion, not an instruction. Decide: *fix* (with a concrete change, refined from the reviewer's suggestion where you can do better), *discard* (wrong, not applicable, or not worth the change, with a reason), or *ask* (a decision only the user can make). For a discard the reviewer disputes, either switch to *fix* or keep discarding once with new reasoning or evidence; if the reviewer still disputes it after that, make it *ask* with both positions.
3. **Bring every round's findings to the user,** even when all are discarded: a table with ID, severity, problem, your call (fix / discard / ask), and the proposed change or reason. Wait for the go-ahead before changing code, unless the user already authorized fixes ("fix what you agree with"); *ask* items always need an answer. If the user asked only for a report, stop after the first table.
4. **Fix** what the user approved and run relevant checks.
5. **Reply** on stdin with `herdr-review reply <name>`:

   ```markdown
   ## Response to round <n>
   - F1 fixed: <what changed, file:line>
   - F2 discarded: <reason, or new evidence if the reviewer disputed it>
   - F3 deferred by the user: <reason>
   Checks: <commands run and results>
   ```

6. **Repeat** steps 2-5 until the reviewer returns `VERDICT: approved` or accepts every remaining discard and deferral, or the user stops.
7. **Finish** with a short summary: what was fixed, what was discarded and why (and whether the reviewer agreed), the number of rounds, and the final verdict. Leave the reviewer's tab open; run `herdr-review cleanup <name>` only when the user asks.

## Exit codes

- `0`: findings printed.
- `3`: the reviewer is blocked on an approval or question. Tell the user which tab; after they answer it, run `herdr-review wait <name>`.
- `4`: still working. Run `herdr-review wait <name>`.
- `5`: it finished without writing findings. Tell the user; inspect with `herdr agent read <name> --source recent-unwrapped --lines 120` only if needed.
