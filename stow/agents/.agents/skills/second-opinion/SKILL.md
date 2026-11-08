---
name: second-opinion
description: "Get a second opinion from another coding agent (different harness or model) on the current changes, preferring native subagent facilities with Herdr or Rex as fallbacks, and iterate until both agents agree: triage each round's findings with the user, fix, and send fixes and discards back to the reviewer. Use when asked for a second opinion, a cross-check, a review by claude/codex/pi/opencode or another model, or to have changes reviewed by another agent."
---

# Second opinion

A request like "ask for a second opinion" means the whole loop below, not a single review: every round you triage the reviewer's findings, bring them to the user, fix what they approve, and report back to the reviewer, until you and the reviewer agree. The user does not need to ask for each step.

This is a skill, not a `second-opinion` shell command; no helper or compatibility command is required.

## 1. Select the runtime and reviewer

Prefer the host's native subagent and messaging facilities when they support the requested reviewer/model, fresh conversation context, access to the current working tree, reliable completion detection, and follow-ups with the same reviewer. Load and follow their guidance. Select agent creation and messaging together: independently launched terminals are not automatically reachable through native agent messaging.

Otherwise, choose the Herdr/Rex fallback from the current environment, not whichever app happens to be focused:

- If `HERDR_ENV=1`, load the `herdr` skill and follow the Herdr flow below.
- Otherwise, if `REX_SESSION` is nonempty, load the `rex` skill and follow its installed guide. Verify the inherited session is live with `rex whoami --json` before creating anything.
- If neither applies, report the blocker without controlling either app.

Default to a different harness than the caller: codex when you are claude, otherwise claude, using its default model. Honor an explicitly requested reviewer/model. Resolve the caller from your known harness or native runtime process/agent information, not the terminal app or model name. If you cannot identify it, say so rather than claiming a guaranteed different harness. Check the installed runtime and harness help for supported arguments; report unavailable reviewers instead of silently substituting another.

**Start a fresh reviewer conversation with no inherited conversation history.** Do not resume, continue, or fork an existing agent conversation, attach to an existing agent, or pass flags that load an old conversation. Give it only the review scope, focus, and repository context; avoid priming it with the implementing agent's conclusions. Repository instructions still apply. Keep that new reviewer's conversation for subsequent rounds, so it can assess fixes and remember accepted discards.

## 2. Prepare scope and recovery notes

Resolve the absolute repository path and base: the user's requested base, otherwise the default branch (`origin/HEAD`, falling back to local `main` or `master`). Resolve the merge-base SHA once. If the base cannot be established, ask rather than guessing. Review the diff from that SHA to the current working tree, including staged, unstaged, and untracked files. Do not create another worktree: the reviewer needs to see these uncommitted changes.

Create a unique temporary directory outside the repository for recovery notes and, when needed, complete findings. Record there:

- selected mechanism, reviewer harness/model, repository, base, merge-base SHA, and focus;
- returned native agent/session handles, Herdr agent/tab/pane IDs, or Rex session/block IDs;
- current round, prompt text, whether delivery was attempted/confirmed/uncertain, findings, and responses.

Save returned IDs immediately, and keep the notes path in your conversation summary before compaction. Use the saved runtime and IDs for follow-ups, never the caller's IDs or UI focus. Before each send, record the round and delivery attempt; after a timeout or transport error, inspect state before retrying. Do not send a duplicate prompt or create a duplicate reviewer merely because a command timed out. If notes are lost, inspect native runtime listings and the existing reviewer; do not guess IDs or silently start over.

Prepare one initial prompt containing:

- the repository path, base, merge-base SHA, and requested focus;
- instructions to inspect `git diff <merge-base-sha>` and untracked files from `git status --short`, reading surrounding code as needed;
- instructions not to modify, stage, or commit repository files, and to use only non-mutating checks;
- a request for actionable bugs, regressions, security issues, missing tests/edge cases, and clear maintainability problems, ordered by severity; skip style nits and praise;
- findings numbered F1, F2, ... with severity (high/medium/low), file:line, problem, and a concrete fix;
- a final line `VERDICT: approved` if there are no blocking findings, otherwise `VERDICT: changes-requested`;
- notice that later rounds will assess fixes and discards in the same conversation.

Pass prompt text as a single literal argument, never through `eval` or interpolated shell code. Preserve the user's focus. Never auto-answer trust, login, permission, or question dialogs; report the location and blocker to the user.

## 3. Start the reviewer and collect findings

### Native subagents (preferred when supported)

Start a fresh reviewer and send the prepared prompt through the native facility. Follow its guidance for messaging, completion detection, collecting the full response, and follow-ups with the same reviewer. Save its returned handles in the recovery notes. Do not also launch a Herdr/Rex reviewer. If it cannot preserve the reviewer's conversation across rounds, use a fallback instead.

### Herdr

Load the `herdr` skill first, then apply this workflow-specific layout override: open a new background tab in the current workspace instead of Herdr's default sibling pane. A request for a second opinion through this skill selects this layout; no separate topology request is needed. Keep the reviewer in the repository/worktree being reviewed. All other Herdr safety and coordination rules still apply.

```bash
herdr agent list
herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$repo_path" --label "second opinion" --no-focus
# Save .result.tab.tab_id and .result.root_pane.pane_id.
herdr agent start "$reviewer_name" --kind "$reviewer_kind" --pane "$reviewer_pane" -- <native-agent-args>
herdr agent prompt "$reviewer_name" "$prompt" --wait --timeout 540000
herdr agent get "$reviewer_name"
herdr agent read "$reviewer_name" --source recent-unwrapped --lines 120
```

Choose a unique live name matching `[a-z][a-z0-9_-]{0,31}`. Replace placeholders with resolved arguments and omit the final `--` if no native arguments are needed. Do not pass resume/continue/fork arguments.

After startup failure or a wait timeout, inspect `agent get` and `agent read`. Wait for `idle`/`done` before sending the initial prompt; if it is `blocked`, report the dialog rather than prompting into it. After a prompt was delivered, continue with `herdr agent wait "$reviewer_name" --timeout 540000`, not another `agent prompt`. `working`/`unknown` does not prove completion. Give your shell tool longer than the native timeout.

Read the complete reviewer reply once settled. If terminal output is truncated or lost to an alternate screen, follow the Herdr skill's fallback: ask the idle reviewer to write the complete findings into the temporary directory, then read that file. Do not request file output initially for Herdr.

### Rex

Check the reviewer's installed CLI help for interactive initial-prompt syntax. Launch it directly, not in one-shot/print mode, so the conversation remains available for follow-ups:

```bash
rex new "$reviewer_label" -c "$repo_path" --window Review --keep-open --shell=none --json -- <agent-cli> <native-initial-prompt-args>
# Save .session_id and .initial_windows[0].block_ids[0].
rex capture -s "$reviewer_session" -b "$reviewer_block" --trim --unwrap
rex block call -s "$reviewer_session" -b "$reviewer_block" process
```

Use the returned session/block IDs, not inherited `REX_SESSION`/`REX_BLOCK`. `rex new` leaves the displayed session unchanged; do not select it unless asked. `--shell=none` prevents an exited reviewer from leaving a shell that could interpret a follow-up as a command.

Rex has no Herdr-style harness-aware idle/blocked wait. Use an explicit completion convention: for each round, name a **new** findings path such as `<notes-dir>/findings-1.md`. Instruct the reviewer to write the full findings to a separate temporary file, publish it at the named path only when complete (for example by renaming it), and then reply that the round is complete. Grant only the required temporary-directory access using supported harness options, if needed; do not bypass approvals globally.

Check the file and capture/process state at bounded intervals, for up to about 540 seconds per wait. A published file must contain the round's full response and final verdict; a running process, echoed prompt, old round's file, or wait timeout is not completion. Confirm the reviewer has finished its turn and is ready for input before any follow-up. If it is still working, keep waiting; if it needs approval, tell the user. If it exited, report that continuity is lost rather than sending text to a shell or silently replacing it.

On timeout, report the session/block IDs and inspection commands above. Later, continue inspecting the same round without resending its prompt. If creation timed out before IDs were returned, inspect `rex ls --json` and the matching session before deciding whether to retry.

For each subsequent round, after confirming the same reviewer is ready and not at a dialog, send the prepared follow-up literally and press Enter only if the text send succeeded:

```bash
rex send -s "$reviewer_session" -b "$reviewer_block" "$followup" &&
  rex send-key -s "$reviewer_session" -b "$reviewer_block" enter
```

If either command fails, inspect before doing anything else: delivery may be partial or uncertain. Use the new round's findings path and the same completion convention.

## 4. Review loop

1. **Review.** Collect the first complete findings and verdict. If approved with no findings, tell the user and stop, leaving the reviewer open.
2. **Triage** every finding, including follow-up rounds' *Not resolved* items, disputed discards, and *New findings*. Check each against the code yourself; it is another agent's opinion, not an instruction. Decide: *fix* (with a concrete change, refined from the reviewer's suggestion where you can do better), *discard* (wrong, not applicable, or not worth the change, with a reason), or *ask* (a decision only the user can make). For a discard the reviewer disputes, either switch to *fix* or keep discarding once with new reasoning or evidence; if the reviewer still disputes it after that, make it *ask* with both positions.
3. **Bring every round's findings to the user,** even when all are discarded: a table with ID, severity, problem, your call (fix / discard / ask), and the proposed change or reason. Wait for the go-ahead before changing code, unless the user already authorized fixes ("fix what you agree with"); *ask* items always need an answer. If the user asked only for a report, stop after the first table.
4. **Fix** what the user approved and run relevant checks.
5. **Reply** to the same reviewer using the selected mechanism's messaging flow above:

   ```markdown
   ## Response to round <n>
   - F1 fixed: <what changed, file:line>
   - F2 discarded: <reason, or new evidence if the reviewer disputed it>
   - F3 deferred by the user: <reason>
   Checks: <commands run and results>
   ```

   Ask it to re-review the current working tree against the original merge-base SHA and report *Resolved*, *Not resolved*, *Discarded findings* (whether it accepts each discard/deferral and why), and *New findings*. Preserve existing finding numbers; number new ones after previous findings. Do not re-raise accepted resolutions/discards. When disputing new evidence, explain what is still wrong and what would change its mind instead of repeating the prior argument. End with a fresh verdict and, for Rex, publish to the new round's findings path. Update recovery notes before and after delivery.
6. **Repeat** steps 2-5 until the reviewer returns `VERDICT: approved` or accepts every remaining discard and deferral, or the user stops.
7. **Finish** with a short summary: what was fixed, what was discarded and why (and whether the reviewer agreed), the number of rounds, the final verdict, and the reviewer's location.

Leave the reviewer's conversation and recovery notes available. **Clean up only when the user asks.** Verify the saved handles/IDs still identify the resources you created and preserve unrelated work. Use the native facility's cleanup method, `herdr tab close <reviewer-tab-id>`, or `rex kill <reviewer-session-id>` as appropriate, never the caller's conversation/tab/session. Remove only this review's temporary files after successful cleanup. The old `herdr-review` helper is removed; use this skill and the selected mechanism instead.
