# Resume claude and pi conversations in blocks that Rex restores after a
# server restart. Rex keeps block IDs and brings each block back as a shell,
# so a record left for this block means its agent was running when the
# server stopped. The record holds the resume command, which is typed at the
# prompt (never run).
#
# Only the block's outermost interactive shell takes part; `exec zsh` keeps
# its pid. The marker names the block, so one inherited from elsewhere (a
# server started from another block) doesn't count. Agents get the record path in REX_RESUME_FILE and hide it from
# their tool shells, so nested agents leave the record alone.

[[ -o interactive && ${REX_BLOCK-} == block:* ]] || return 0
[[ ${REX_RESUME_SHELL%:*} != "$REX_BLOCK" || ${REX_RESUME_SHELL##*:} == "$$" ]] || return 0
export REX_RESUME_SHELL=$REX_BLOCK:$$

typeset -g _rex_resume_file=${XDG_STATE_HOME:-$HOME/.local/state}/rex-resume/${REX_BLOCK#block:}

# A server restart kills this shell before the rm, keeping the record.
_rex_resume_run() {
  REX_RESUME_FILE=$_rex_resume_file command "$@"
  local rc=$?
  rm -f -- "$_rex_resume_file"
  return $rc
}

claude() { _rex_resume_run claude "$@" }
pi() { _rex_resume_run pi "$@" }

[[ -r $_rex_resume_file ]] && print -z -- "$(<"$_rex_resume_file")"
