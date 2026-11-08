---
name: subagent
description: Use the subagent tool to spawn and communicate with observable Pi child agents for independent investigations and delegated implementation work.
---

# Subagent

Use the **subagent tool**, not bash or a CLI. Each child is a separate Pi process
with its own context. Children of one parent share a Rex session, one tab per child.
Managed children cannot manage nested subagents and do not load this skill.

## Spawn

Call the tool with:

```json
{
  "action": "spawn",
  "name": "investigation",
  "group": "auth refactor",
  "prompts": ["Investigate the authentication flow and report findings without modifying files."]
}
```

Give children descriptive names. Use a short group label (2–4 words, at most 24
characters) describing the parent's task. The first spawn sets the shared Rex
session label; later spawns reuse it. Keep the returned handle for later calls.

Provider, model, reasoning level, working directory, and parent session identity
come directly from the current Pi context, not shell environment variables.
Set `provider`, `model`, or `thinking` only when deliberately choosing overrides.
`cwd` is relative to the parent's working directory. `files` paths are also resolved
relative to the parent, and are sent as Pi file attachments. Provide at least one
nonempty prompt or file. Multiple `prompts` and `files` are supported.

## Tools and isolation

Omit `tools` to inherit normal child defaults and configuration. To constrain a
read-only investigation, use `tools: ["read", "grep", "find", "ls"]`. Bash can
modify files and is not a read-only capability.

Optional spawn flags:

- `noExtensions`: disable normal extension discovery; the child control bridge is still explicitly loaded.
- `noSkills`: hide installed skills.
- `noPromptTemplates`: disable prompt templates.
- `noContextFiles`: ignore repository instruction files; avoid for implementation work.

An unrecognized project trust context is declined rather than leaving the child
blocked on a trust prompt. Stored project trust decisions are respected.

## Inspect, communicate, and wait

```json
{"action": "list"}
{"action": "status", "handle": "abc123"}
{"action": "rename", "handle": "abc123", "name": "auth review"}
{"action": "send", "handle": "abc123", "message": "Also check token expiry"}
{"action": "send", "handle": "abc123", "message": "Review the tests next", "followUp": true}
{"action": "wait", "handle": "abc123", "timeoutSeconds": 1800}
```

`list` and handle-based actions are scoped to the current parent session.
`send` prompts an idle child or steers a busy one. With `followUp`, the message
waits until the busy child finishes. Use this tool's inbox, not `rex send`.

`wait` returns the latest assistant response from the durable active session
branch. Do not infer completion from terminal text. It defaults to 1800 seconds;
cancelling the call stops waiting but leaves the child running. Responses are
limited to 50KB/2000 lines; the result includes the transcript path for full output.

## Lifecycle and cleanup

Children remain alive after completing a turn and survive `/reload`. Quitting or
switching away from the parent suspends them; resuming the parent relaunches them
with their saved transcripts. Becoming idle, waiting, and cancellation do not
terminate children.

Explicitly stop every child when it is no longer needed:

```json
{"action": "stop", "handle": "abc123"}
```

This closes the Rex tab (and its shared session after the last tab) and removes run
metadata. Transcripts remain under `~/.pi/agent/subagents/sessions/` (or the custom
`PI_CODING_AGENT_DIR`). Keep a child idle only for concrete expected follow-up work.
