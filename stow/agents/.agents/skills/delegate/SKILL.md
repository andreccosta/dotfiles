---
name: delegate
description: "Delegate a particular Linear ticket to a new coding agent in its own worktrunk branch/worktree, preferring the host's native subagent facilities with Herdr or Rex as fallbacks. Use when the user asks to delegate, hand over or spin off work on an identified Linear ticket to another agent. Not applicable to requests without a Linear ticket."
---

# Delegate

Hand a Linear ticket to a fresh agent in an isolated worktree. Do not do the task yourself or wait for it to finish.

Inputs, from the user's request or the conversation:

- **Task**: a required Linear ticket ID (e.g. `SAAS-3774`), supplied directly or identified by a Linear URL or the conversation.
- **Harness**: spawn a fresh agent using the same harness as the calling agent, unless the user explicitly requests another. Resolve its supported Herdr kind or installed CLI; do not infer the harness from the terminal app or model name. If it cannot be identified or launched, report the blocker rather than silently substituting another.
- **Base**: the default branch unless the user names another.

## 1. Understand the task

Resolve the ticket ID and, unless its title and type are already known from the conversation, fetch them with the Linear tools. You only need enough to name the branch and write a good handoff; the new agent reads the full ticket itself.

## 2. Create the branch and worktree with worktrunk

Name the branch `<prefix>/<ticket-id-lowercase>-<short-kebab-summary>`, where the prefix is `fix/` for bugs, `feat/` for features and `chore/` for everything else. Example: `fix/saas-3774-exclusion-api-pagination`.

```bash
wt switch -c <branch> --no-cd            # add -b <base> if a base was given
```

Always create with worktrunk, not `git worktree add` or `herdr worktree create`, so configured setup hooks run. `herdr worktree open` only opens the existing worktree. Post-start hooks may still be running when `wt switch` returns.

## 3. Choose the runtime and prepare the handoff

Prefer the host's native subagent and messaging facilities when they support the requested harness, a fresh agent in the isolated worktree, and a handoff that can continue independently. Load and follow their guidance. Select agent creation and messaging together: independently launched terminals are not automatically reachable through native agent messaging.

Otherwise, choose the Herdr/Rex fallback from the current environment, not whichever app happens to be focused:

- If `test "${HERDR_ENV:-}" = 1` passes, follow the Herdr flow below and load the `herdr` skill first.
- Otherwise, if `REX_SESSION` is nonempty, follow the Rex flow below and load the `rex` skill first. Verify the inherited session is live with `rex whoami --json` before creating anything.
- If neither applies, do not control either app. Look up the worktree path with the command below, report the branch and path, suggest `wt switch <branch> -x <agent-cli>`, and stop.

For native subagents, Rex, or the outside-app fallback, obtain the absolute worktree path with structured output; require exactly one nonempty matching path before continuing:

```bash
wt list --format=json | jq -er --arg branch '<branch>' '[.items[] | select(.branch == $branch) | .worktree.path | select(type == "string" and length > 0)] | if length == 1 then .[0] else error("expected one worktree path") end'
```

Prepare one handoff for the selected mechanism. It should:

- name the ticket and its title, and tell the agent to read the full ticket and its comments with the Linear tools first;
- name the branch and base, and tell it to check any background setup hooks have finished before running tests;
- state the goal in one or two sentences, plus any context or decisions from this conversation the agent can't find elsewhere (files already identified, approaches ruled out, user preferences);
- tell it to follow the repository's instructions for testing and linting;
- tell it not to commit, push or open a PR until the user asks, and to finish with a summary of the root cause and the fix (or of what was done).

## 4. Start the agent and hand over

Pass handoff text as a single literal argument, never as shell code or through `eval`. Preserve the user's focus. Inspect startup failures or approval dialogs and report blockers rather than approving them. After a timeout, inspect state before retrying to avoid duplicates.

### Native subagents (preferred when supported)

Use the native facility to start a fresh agent in the resolved worktree and deliver the prepared handoff. Follow its guidance for messaging, pickup confirmation, and any completion notifications. Save the returned agent/session handle and report it to the user. Do not also launch a Herdr/Rex agent.

### Herdr: open a workspace for the worktree

Load the `herdr` skill first, then apply this workflow-specific layout override: open the isolated worktree in its own background workspace instead of Herdr's default sibling pane in the caller's working directory. A request to delegate through this skill selects this layout; no separate topology request is needed. All other Herdr safety and coordination rules still apply.

```bash
herdr worktree open --cwd "$PWD" --branch <branch> --label <ticket-id-lowercase> --no-focus
# inspect the response for the opened workspace ID and worktree path
# use herdr pane list --workspace <workspace-id> to find its available shell pane
herdr agent start <ticket-id-lowercase> --kind <kind> --pane <pane-id> --timeout 60000
```

The agent name must match `[a-z][a-z0-9_-]{0,31}` and must not clash with a live agent. Check with `herdr agent list` and add a suffix if needed.

Send the prepared handoff with `herdr agent prompt <name> "<handoff>"`, without `--wait`.

Confirm pickup with `herdr agent get <name>` and, if needed, `herdr agent read <name>`. Expect `working`, but inspect output if it already finished or is blocked.

### Rex: create a new session

Set `handoff` to the prepared text and `worktree_path` to the resolved path. Check the resolved harness's CLI help for its interactive initial-prompt syntax, then create the session:

```bash
rex new <ticket-id-lowercase> -c "$worktree_path" --window Agent --json -- <agent-cli> <initial-prompt-args>
```

Replace the command placeholders with the harness's CLI and arguments that pass `"$handoff"` as its initial prompt. Do not use a one-shot/print mode; the user must be able to continue the conversation.

Save `.session_id` and `.initial_windows[0].block_ids[0]` from the response. Use these new IDs, not the caller's inherited `REX_SESSION`/`REX_BLOCK`. `rex new` leaves the user's displayed session unchanged; do not select it unless asked.

Confirm the agent started and received the task by inspecting the new block:

```bash
rex capture -s <new-session-id> -b <new-block-id> --trim --unwrap
rex block call -s <new-session-id> -b <new-block-id> process
```


## 5. Report

Tell the user the branch, the worktree path, the harness, and whether the handoff succeeded or startup is blocked. Include the mechanism-specific location and how to check on it:

- **Native subagents**: returned agent/session handle and the facility's supported inspection or continuation method.

- **Herdr**: workspace label/ID, agent name, and `herdr agent read <name>` (or switch to the workspace).
- **Rex**: new session label/ID, agent block ID, and `rex capture -s <new-session-id> -b <new-block-id> --trim --unwrap` (or select the session in Rex).
