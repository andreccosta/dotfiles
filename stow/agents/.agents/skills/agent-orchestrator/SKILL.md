---
name: agent-orchestrator
description: "Orchestrate ticket work in Worktrunk worktrees and Herdr workspaces. Use when asked to start an isolated agent for a Linear ticket or task, monitor or review that work, or clean up its workspace and worktree."
---

# Agent Orchestrator

Coordinate agents through Herdr, with isolated branches and worktrees managed by Worktrunk. This skill explicitly permits delegation for the requested task. Load the `herdr` skill and follow its lifecycle and terminal-control rules; use Herdr agents rather than in-process subagents.

## Defaults

- Agent kind: the kind the user requests; otherwise the same kind as the calling agent, so an orchestrator spawns peers of itself. If the caller's kind cannot be determined, ask. Use the agent's default (implementation) mode for implementation and its native read-only or planning mode, when it has one, for research or planning. Inherit the configured model unless the user specifies one.
- Base: Worktrunk's default branch. Use the requested base when provided; use `--base=@` only when the task should start from the caller's current HEAD.
- Branch and workspace: lowercase ticket ID plus short slug, e.g. `am-1234-fix-export`. Without a ticket, use a short task slug.
- Agent name: lowercase ticket ID, e.g. `am-1234`; otherwise task slug. Names must match `[a-z][a-z0-9_-]{0,31}` and be unique among live agents.
- Setup: honor repo instructions and configured Worktrunk hooks. For a no-code smoke test, use `--no-hooks` on creation and removal.
- Deliverable: implement requested scope, run relevant checks, summarize changes and blockers. Commit, push, open PRs, or update Linear only when requested.
- Keep workspaces open for review. Preserve user focus with `--no-focus`.

## Resolve context and inspect

1. Verify `test "${HERDR_ENV:-}" = 1` before any Herdr control command. If false, stop and explain that orchestration requires a Herdr-managed pane.
2. Confirm the target repo from the request or cwd. Read applicable `AGENTS.md` files and inspect Git status; preserve existing work.
3. Resolve ticket content through available Linear tooling. Capture title, description, acceptance criteria, and relevant linked context. If access is unavailable, ask for pasted context; do not invent requirements from an ID.
4. Discover installed commands with `herdr --help`, `herdr workspace`, `herdr agent`, `herdr agent start --help` (supported kinds), `wt switch --help`, and `wt remove --help`.
5. Resolve the agent kind. If the user did not request one, find the calling agent's kind in `herdr agent list` by matching `$HERDR_PANE_ID`. Confirm the kind's executable is installed and read its `--help` for native mode and model flags; do not assume flags from another agent.
6. Inspect `wt list --format json`, `herdr workspace list`, and `herdr agent list`. Resume a matching tracked task when appropriate. Never overwrite an existing branch, directory, workspace, or agent; resolve ambiguous matches before acting.

Use explicit repo working directories for Worktrunk/Git commands. JSON schemas can vary by installed version; read actual responses rather than assuming list shapes.

## Track tasks across conversations

Keep a Markdown record per task at `${XDG_STATE_HOME:-$HOME/.local/state}/agent-orchestrator/<repo-slug>/<task-slug>.md`, outside the worktree and dotfiles. Use filesystem tools to write it; verify parent directories before creating them.

Record and update after each successful step:

- Ticket ID/URL or task summary; acceptance criteria and user constraints.
- Absolute repo path, base branch and initial base SHA, branch and worktree path.
- Herdr session identity from available session/caller context, workspace ID, pane ID, agent name/kind, and agent session ID when exposed.
- Which resources this task created, whether hooks were skipped, and timestamps.
- State: setting-up, working, blocked, ready-for-review, or cleaned-up.
- Latest result, checks, blockers, and review findings.

Treat records as a lookup aid, not live truth. Revalidate repo, workspace, pane, and agent identity before sending prompts or closing resources. IDs belong to a session; do not use recorded IDs against another session. If a pane moves, update its returned pane ID. Do not store credentials or entire ticket transcripts.

## Create worktree, workspace, and agent

Run these steps sequentially; every later step uses identifiers returned by the preceding step. The shell variables below represent resolved values, not literal placeholders to send.

1. Verify the configured worktree parent location exists and is intended. Create through Worktrunk in the target repo:

   ```bash
   wt switch --create "$BRANCH" --no-cd --format json
   ```

   Add `--base "$BASE"` when specified. For a smoke test, add `--no-hooks`. Read the returned `path` and `branch`; do not predict the path. Track whether the branch/worktree was actually created by this task. Do not blanket-approve hooks with `--yes`; surface approvals when needed.

2. Create the workspace rooted in that exact path:

   ```bash
   herdr workspace create --cwd "$WORKTREE_PATH" --label "$LABEL" --no-focus
   ```

   Read `.result.workspace.workspace_id` and `.result.root_pane.pane_id`.

3. Start the resolved agent kind in the returned shell pane:

   ```bash
   herdr agent start "$AGENT_NAME" --kind "$AGENT_KIND" --pane "$PANE_ID"
   ```

   Pass native agent arguments, such as a planning mode or requested model, only after `--`, using the flags discovered from that agent's `--help`. Do not add permission-bypass flags. Wait for interactive readiness before prompting.

4. Send a self-contained assignment with `herdr agent prompt`. Include:
   - Ticket details and acceptance criteria, not just a link.
   - Worktree path, requested scope, user constraints, and relevant repo discoveries.
   - Instructions to read applicable repo guidance, make minimal changes, and run relevant checks.
   - Authorized commit/PR actions, if any.
   - Final report: summary, changed files, checks/results, unresolved issues.
   - Stay in this worktree; do not orchestrate more agents or close/remove resources.

   For a smoke test, simply request: `Reply with exactly: Hello world! Do not use tools or modify any files.`

5. Report branch, worktree, workspace, and agent to the user. If asked only to start, return after dispatch and record working state. If asked to complete or monitor, continue through verification.

If setup fails partway, record the resources that exist and the blocker. Inspect live state before retrying; do not create duplicate agents or silently remove useful work.

## Monitor and review

- Use `herdr agent prompt "$AGENT_NAME" "$ASSIGNMENT" --wait --timeout 120000` for short tasks. For longer work, dispatch without `--wait`, then use bounded `herdr agent wait` calls as needed. A timeout alone is not a task failure.
- On completion, timeout, or error, inspect `herdr agent get` and `herdr agent read --source recent-unwrapped --lines 120` with the explicit agent target. `done`/`idle` is a lifecycle signal; verify the response and deliverable. `unknown` does not prove completion.
- If blocked, read the approval/question UI and surface it to the user before responding. Do not send another assignment into a blocked agent.
- If output is truncated, follow the Herdr skill's larger-read/file-output fallback. Avoid busy polling.
- For implementation review, inspect Git status and the diff in the tracked worktree, including new files and committed changes since the initial base SHA. Compare against acceptance criteria and the agent's reported checks. Return concrete findings or prompt the same agent to fix issues within the original scope.
- Verify the final result before recording ready-for-review. Report status, important changes, checks, and blockers concisely.
- Monitoring occurs while actively executing or when the user asks again; do not promise unattended notifications after this turn ends.

## Cleanup on request

1. Resolve the tracked task and verify live workspace, worktree, and agent identities. Inspect worktree Git status and whether unmerged commits exist. Surface unfinished work or data that removal would discard; do not use force flags without explicit authorization.
2. Close the task's workspace with `herdr workspace close "$WORKSPACE_ID"`, stopping its agent before removing its cwd. Close only the matched workspace authorized for cleanup; never the orchestrator's workspace.
3. From the surviving repo, remove through Worktrunk:

   ```bash
   wt remove "$BRANCH" --foreground --format json
   ```

   Add `--no-hooks` for a smoke test created without hooks. Worktrunk deletes integrated branches by default and retains unmerged branches. Use `--no-delete-branch` when requested. Never substitute raw directory deletion.
4. Read the removal result, including `branch_outcome`; verify workspace/worktree absence using live lists. Record cleaned-up state only after successful cleanup and report whether the branch was deleted or retained. Keep the task record for future lookup.

## Example requests

- “Start AM-1234 in a new workspace and worktree.”
- “Start an agent to implement this pasted task, then monitor and review it.”
- “Check AM-1234.” / “Review AM-1234.” / “Clean up AM-1234.”
- “Smoke-test orchestration: create a worktree and workspace, then have an agent say hello world.”
