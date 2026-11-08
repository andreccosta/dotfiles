# Pi subagents

Adapted from [gmcabrita/dotfiles](https://github.com/gmcabrita/dotfiles/tree/b766903b5f6046de1201e8d013cf30d4c5b96083/.pi/agent/extensions/subagent).

The parent registers a typed `subagent` tool with `spawn`, `status`, `rename`,
`send`, `wait`, `stop`, and `list` actions. No shell wrapper or standalone CLI is
needed. Requires `rex` and `pi` on PATH to host children in Rex terminals.

Local changes:

- Replaced the upstream CLI with tool-facing `operations.ts` and `tool.ts`.
- Read model, reasoning, cwd, and session identity directly from Pi context.
- Scope handle operations to the current parent session.
- Make wait polling asynchronous and cancellation-aware; cancellation leaves the child alive.
- Bound tool output to 50KB/2000 lines and return run identifiers/transcript paths in details.
- Explicitly load the child control bridge even when normal extensions are disabled.
- Update the bundled skill to describe the tool rather than CLI commands.

The extension discovers `skills/subagent/SKILL.md` automatically in parent sessions.
Run `/reload` after installation. Children survive reload, suspend when the parent
quits or switches, and resume with the parent. Stop finished children explicitly;
their transcripts are retained.

Tests (no live Pi agents or Rex sessions are started):

```sh
npm --prefix stow/pi/.pi/agent run test:subagent
```
