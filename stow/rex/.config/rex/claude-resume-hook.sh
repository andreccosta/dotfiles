#!/bin/sh
# Claude Code SessionStart and Stop hook: record the conversation so a block
# Rex restores can resume it. See resume.zsh.

[ -n "${REX_RESUME_FILE:-}" ] || exit 0

# Hide the record from tool shells so nested agents leave it alone.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'unset REX_RESUME_FILE' >>"$CLAUDE_ENV_FILE"
fi

input=$(cat)
# Subagents report their own agent_id; only the main conversation counts.
id=$(printf %s "$input" | jq -r 'select(.agent_id == null) | .session_id // empty') || exit 0
transcript=$(printf %s "$input" | jq -r '.transcript_path // empty') || exit 0
# Claude saves a conversation after its first message; skip it until then.
[ -n "$id" ] && [ -f "$transcript" ] || exit 0

mkdir -p "$(dirname "$REX_RESUME_FILE")"
printf 'claude --resume %s\n' "$id" >"$REX_RESUME_FILE"
