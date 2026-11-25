---
name: second-opinion
description: "Get a second opinion from another coding agent (different harness or model) on the current changes, preferring native subagent facilities with Rex as fallback. Iterate directly with the reviewer, escalating to the user only significant direction changes or open questions. Use when asked for a second opinion, a cross-check, a review by claude/codex/pi/opencode or another model, or to have changes reviewed by another agent."
---

# Second opinion

A request like "ask for a second opinion" means the whole loop below. Run it with the reviewer yourself; involve the user only for *ask* items and the final summary. Honor explicit limits (e.g. report-only, round limit).

## 1. Select the runtime and reviewer

Prefer the host's native subagent and messaging facilities when they support the requested reviewer/model, fresh conversation context, access to the current working tree, reliable completion detection, and follow-ups with the same reviewer. Load and follow their guidance. Launch and messaging must use the same mechanism, or peer messaging (see below).

Otherwise, if `REX_BLOCK` is nonempty, load the `rex` skill and follow the Rex flow below. Verify the inherited session is live with `rex whoami --json` before creating anything. If not, report the blocker.

Default to a different harness than the caller: codex when you are claude, otherwise claude, using its default model. Honor an explicitly requested reviewer/model. Resolve the caller from your known harness or native runtime process/agent information, not the terminal app or model name. If you cannot identify it, say so rather than claiming a guaranteed different harness. Check the installed runtime and harness help for supported arguments; report unavailable reviewers instead of silently substituting another.

**Start a fresh reviewer conversation with no inherited conversation history.** Do not resume, continue, or fork an existing agent conversation, attach to an existing agent, or pass flags that load an old conversation. Give it only the review scope, focus, and repository context; avoid priming it with the implementing agent's conclusions. Repository instructions still apply. Keep that new reviewer's conversation for subsequent rounds, so it can assess fixes and remember accepted discards.

## 2. Prepare scope and recovery notes

Resolve the absolute repository path and base: the user's requested base, otherwise the default branch (`origin/HEAD`, falling back to local `main` or `master`). Resolve the merge-base SHA once. If the base cannot be established, ask rather than guessing. Review the diff from that SHA to the current working tree, including staged, unstaged, and untracked files. Do not create another worktree: the reviewer needs to see these uncommitted changes.

Create a unique temporary directory outside the repository for recovery notes and, when needed, complete findings. Record there:

- selected mechanism, reviewer harness/model, repository, base, merge-base SHA, and focus;
- returned native agent/session handles or Rex session/block IDs;
- current round, prompt text, whether delivery was attempted/confirmed/uncertain, findings, and responses.

Save returned IDs immediately, and keep the notes path in your conversation summary before compaction. Use the saved runtime and IDs for follow-ups, never the caller's IDs or UI focus. Before each send, record the round and delivery attempt; after a timeout or transport error, inspect state before retrying. Do not send a duplicate prompt or create a duplicate reviewer merely because a command timed out. If notes are lost, inspect native runtime listings and the existing reviewer; do not guess IDs or silently start over.

Prepare one initial prompt containing:

- the repository path, base, merge-base SHA, and requested focus;
- instructions to inspect `git diff <merge-base-sha>` and untracked files from `git status --short`, reading surrounding code as needed;
- instructions not to modify, stage, or commit repository files, and to use only non-mutating checks;
- a request for actionable bugs, regressions, security issues, missing tests/edge cases, and clear maintainability problems, ordered by severity; skip style nits and praise;
- findings numbered F1, F2, ... with severity (high/medium/low), file:line, problem, and a concrete fix;
- a final line `VERDICT: approved` if there are no blocking findings, otherwise `VERDICT: changes-requested`;
- notice that this is a multi-round review in the same conversation: re-check fixes, assess discards, and for disputes say what evidence would change its mind. Direct all questions to the implementing agent, never the user; don't wait for user input.

Pass prompt text as a single literal argument, never through `eval` or interpolated shell code. Never auto-answer trust, login, permission, or question dialogs; report the location and blocker to the user.

## 3. Start the reviewer and collect findings

### Native subagents (preferred when supported)

Start a fresh reviewer and send the prepared prompt through the native facility. Follow its guidance for messaging, completion detection, collecting the full response, and follow-ups with the same reviewer. Do not also launch a Rex reviewer. If it cannot preserve the reviewer's conversation across rounds, use Rex instead.

### Peer messaging (Rex launch, peer delivery)

When both the caller and the reviewer are harness sessions that can message local peers (for example Claude Code's `ListAgents`/`SendMessage`), launch the reviewer through Rex as below but exchange every prompt and response through peer messaging instead of findings files or terminal scraping:

- Launch the reviewer with a unique session name (e.g. `claude --name <reviewer-name>`), and no extra directory grants: it needs no notes-directory access.
- Resolve your own peer name (e.g. from `ListAgents`) and include it in the initial prompt. Instruct the reviewer to send its complete response, ending with the verdict, to that name via peer messaging when the round is done, and to keep its terminal reply to a one-line pointer.
- Confirm the reviewer appears in the peer listing before sending follow-ups. Send each follow-up to the reviewer's name via peer messaging; do not type into its terminal.
- The arrival of the reviewer's message is the completion signal; do not poll for it. Use terminal capture only to detect startup failures, dialogs, or an exited reviewer, and report those to the user.
- If peer messaging fails or the reviewer never appears as a peer, fall back to the Rex completion convention below.

### Rex

Check the reviewer's installed CLI help for interactive initial-prompt syntax. Launch it directly, not in one-shot/print mode, so the conversation remains available for follow-ups:

```bash
rex new "$reviewer_label" -c "$repo_path" --window Review --keep-open --shell=none --json -- <agent-cli> <native-initial-prompt-args>
# Save .session_id and .initial_windows[0].block_ids[0].
rex capture -s "$reviewer_session" -b "$reviewer_block" --trim --unwrap
rex block call -s "$reviewer_session" -b "$reviewer_block" process
```

Use the returned session/block IDs, not inherited `REX_BLOCK`. `rex new` leaves the displayed session unchanged; do not select it unless asked. `--shell=none` prevents an exited reviewer from leaving a shell that could interpret a follow-up as a command.

Rex has no harness-aware idle/blocked wait. Prefer peer messaging (above) when available; otherwise use an explicit completion convention: for each round, name a **new** findings path such as `<notes-dir>/findings-1.md`. Instruct the reviewer to write the full findings to a separate temporary file, publish it at the named path only when complete (for example by renaming it), and then reply that the round is complete. Grant only the required temporary-directory access using supported harness options, if needed; do not bypass approvals globally.

Check the file and capture/process state at bounded intervals, for up to about 540 seconds per wait. A published file must contain the round's full response and final verdict; a running process, echoed prompt, old round's file, or wait timeout is not completion. Confirm the reviewer has finished its turn and is ready for input before any follow-up. If it is still working, keep waiting. If it exited, report that continuity is lost rather than sending text to a shell or silently replacing it.

On timeout, report the session/block IDs and inspection commands above. If creation timed out before IDs were returned, inspect `rex ls --json` and the matching session before deciding whether to retry.

For each subsequent round, after confirming the same reviewer is ready and not at a dialog, send the prepared follow-up literally and press Enter only if the text send succeeded:

```bash
rex send -s "$reviewer_session" -b "$reviewer_block" "$followup" &&
  rex send-key -s "$reviewer_session" -b "$reviewer_block" enter
```

If either fails, delivery may be partial; inspect first. Use the new round's findings path.

## 4. Review loop

1. **Review.** Collect the first complete findings and verdict. If approved with no findings, tell the user and stop, leaving the reviewer open.
2. **Triage** every finding (including *Not resolved*, disputed discards, *New findings*) against the code and agreed scope; it's an opinion, not an instruction:
   - *Fix*: clear outcome within the agreed direction. Refine the suggestion as needed.
   - *Discard*: wrong, not applicable, or not worth it. Give a reason. If disputed, settle it from code, tests, or new evidence. If it hinges on intent, make it *ask*; if neither agent can settle it, mark it a *stalemate* and stop arguing it.
   - *Out of scope*: valid but beyond the agreed scope. Give a reason.
   - *Ask*: changes an agreed requirement, public contract, scope, architecture, or direction, or the intended outcome is unclear. Discuss with the reviewer first if that might settle it.
3. **Escalate *ask* items only**: decision, options/tradeoffs, recommendation. Don't change affected code until the user answers; keep working on everything else. Silence or reviewer agreement isn't approval. User decisions, including deferrals, are final. Report-only: present round 1 triage and stop.
4. **Fix** and run relevant checks.
5. **Reply** to the same reviewer using the selected mechanism's messaging flow above, including user decisions and items still awaiting one:

   ```markdown
   ## Response to round <n>
   - F1 fixed: <what changed, file:line>
   - F2 discarded: <reason, or new evidence if the reviewer disputed it>
   - F3 deferred by the user (final): <reason>
   - F4 awaiting user decision: <open question>
   - F5 out of scope: <reason>
   Checks: <commands run and results>
   ```

   Ask it to re-review the current working tree against the original merge-base SHA and report *Resolved*, *Not resolved*, *Discarded findings* (whether it accepts each discard and out-of-scope call and why; for user deferrals, any residual risk without reopening them), and *New findings*. Preserve existing finding numbers; number new ones after previous findings. Do not re-raise accepted resolutions/discards. When disputing new evidence, explain what is still wrong and what would change its mind instead of repeating the prior argument. End with a fresh verdict, delivered the same way as round 1. Update recovery notes before and after delivery.
6. **Repeat** until both agents agree there are no unresolved findings on the latest tree. A verdict alone isn't enough. If only *ask* items remain, pause until the user answers, then act on it and continue at step 5. If the same issues keep coming back without new evidence or progress, stop and bring the remaining items to the user.
7. **Finish** with one summary: fixed, discarded (and whether the reviewer agreed), out of scope, stalemates, rounds, final verdict, reviewer location. Report stalemates as unresolved, not approved.

Leave the reviewer's conversation and recovery notes available. **Clean up only when asked:** verify saved handles/IDs still identify what you created, close only that reviewer (native cleanup or `rex kill <reviewer-session-id>`), never the caller's, then delete this review's temp dir.
