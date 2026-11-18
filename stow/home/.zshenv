# shared environment (loaded by every zsh invocation)
export LANG=en_US.UTF-8

# Cache for compdump and generated shell-init scripts.  Defined here so both
# .zprofile and .zshrc can use it.
_ZSH_CACHE_DIR="$HOME/.zsh_cache"
[[ -d "$_ZSH_CACHE_DIR" ]] || mkdir -p "$_ZSH_CACHE_DIR"

# _zsh_cached_init <tool> [args...]
# Sources the output of `<tool> args` from ~/.zsh_cache/init-<tool>.zsh,
# regenerating it when the tool's binary is newer (i.e. after an upgrade).
# No-op if <tool> is not on PATH.
_zsh_cached_init() {
  local bin_path cache="$_ZSH_CACHE_DIR/init-${1:t}.zsh"
  bin_path="$(command -v "$1")" || return 1

  if [[ ! -s "$cache" || "${bin_path:A}" -nt "$cache" ]]; then
    "$@" > "$cache" || { rm -f "$cache"; return 1 }
  fi

  source "$cache"
}

# PATH handling (idempotent)
typeset -U path PATH

[[ -r ~/.path ]] && source ~/.path

[[ -r ~/.exports ]] && source ~/.exports

# local env
[[ -r ~/.env ]] && source ~/.env
