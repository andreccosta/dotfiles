# Subagent extension

Imported unchanged from [gmcabrita/dotfiles](https://github.com/gmcabrita/dotfiles/tree/a077ef43508892bdfba71b040a9d26738b49cd23/.pi/agent/extensions/subagent)
at commit `a077ef43508892bdfba71b040a9d26738b49cd23`, together with its
`.local/bin/subagent` launcher (stored in this repository under `stow/pi/`).

Requires Pi, Rex, and a Node.js version that runs TypeScript directly (22.18+).
Run `./dot install pi` to link the launcher, ensure `~/.local/bin` is on `PATH`,
then `/reload` in Pi (or start a new session).

The extension discovers its bundled `subagent` skill automatically in parent
sessions. Follow that skill for spawning, waiting, messaging, and cleanup.
Children are separate Pi processes with fresh context, hosted in one Rex
session per parent, with one tab per child. They inherit the active provider,
model, and thinking level unless explicitly overridden; this does not launch
Claude Code or Codex harnesses.

Control metadata and transcripts live under `${PI_CODING_AGENT_DIR:-~/.pi/agent}/subagents/`.
`subagent stop` removes a child's control state and Rex tab, but preserves its
transcript. Parent quit/session replacement suspends children; resuming the
parent restores them. `/reload` leaves children running.

To update, copy the upstream extension directory and launcher from the same
revision, preserve this local README, and update the revision above.
