# performance optimizations
ZSH_DISABLE_COMPFIX=true
_ZSH_CACHE_DIR="$HOME/.zsh_cache"
mkdir -p "$_ZSH_CACHE_DIR"

# interactive colors
export CLICOLOR=1
export LSCOLORS="exfxcxdxbxegedabagacad"

# Use vivid for modern LS_COLORS themes - cached for performance
if command -v vivid >/dev/null 2>&1; then
  VIVID_CACHE="$HOME/.cache/ls_colors"
  if [[ ! -f "$VIVID_CACHE" ]]; then
    mkdir -p "$HOME/.cache"
    vivid generate tokyonight-night > "$VIVID_CACHE"
  fi
  export LS_COLORS="$(<"$VIVID_CACHE")"
fi

# shared interactive shell files
[[ -r ~/.aliases && -f ~/.aliases ]] && source ~/.aliases
[[ -r ~/.functions && -f ~/.functions ]] && source ~/.functions
[[ -r ~/.extra && -f ~/.extra ]] && source ~/.extra

case "$OSTYPE" in
  linux*)
    [[ -r ~/.linux && -f ~/.linux ]] && source ~/.linux
    ;;
  darwin*)
    [[ -r ~/.osx && -f ~/.osx ]] && source ~/.osx
    ;;
esac

# history
HISTFILE=~/.zsh_history
HISTSIZE=500000
SAVEHIST=500000

setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE # ignore history for commands starting with space
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY # share history between sessions

# options
setopt AUTO_PUSHD # push old dir to stack
setopt CDABLE_VARS # expand (allow 'cd -2/tmp')
setopt AUTO_CD # cd without typing cd
setopt COMPLETE_IN_WORD # better completion
setopt GLOB_DOTS # include dotfiles in completions
setopt NO_BEEP # disable annoying beeps
setopt NOTIFY # report background job status immediately

# key bindings - optimized for speed
typeset -g -A key

# Ensure terminfo is loaded before reading key capabilities.
zmodload zsh/terminfo 2>/dev/null

if (( ${+terminfo} )); then
  key[Home]="${terminfo[khome]:-}"
  key[End]="${terminfo[kend]:-}"
  key[Insert]="${terminfo[kich1]:-}"
  key[Backspace]="${terminfo[kbs]:-}"
  key[Delete]="${terminfo[kdch1]:-}"
  key[Up]="${terminfo[kcuu1]:-}"
  key[Down]="${terminfo[kcud1]:-}"
  key[Left]="${terminfo[kcub1]:-}"
  key[Right]="${terminfo[kcuf1]:-}"
  key[PageUp]="${terminfo[kpp]:-}"
  key[PageDown]="${terminfo[knp]:-}"
  key[Shift-Tab]="${terminfo[kcbt]:-}"

  [[ -n "${key[Home]}"      ]] && bindkey -- "${key[Home]}"       beginning-of-line
  [[ -n "${key[End]}"       ]] && bindkey -- "${key[End]}"        end-of-line
  [[ -n "${key[Insert]}"    ]] && bindkey -- "${key[Insert]}"     overwrite-mode
  [[ -n "${key[Backspace]}" ]] && bindkey -- "${key[Backspace]}"  backward-delete-char
  [[ -n "${key[Delete]}"    ]] && bindkey -- "${key[Delete]}"     delete-char
  [[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"         up-line-or-history
  [[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"       down-line-or-history
  [[ -n "${key[Left]}"      ]] && bindkey -- "${key[Left]}"       backward-char
  [[ -n "${key[Right]}"     ]] && bindkey -- "${key[Right]}"      forward-char
  [[ -n "${key[PageUp]}"    ]] && bindkey -- "${key[PageUp]}"     beginning-of-buffer-or-history
  [[ -n "${key[PageDown]}"  ]] && bindkey -- "${key[PageDown]}"   end-of-buffer-or-history
  [[ -n "${key[Shift-Tab]}" ]] && bindkey -- "${key[Shift-Tab]}"  reverse-menu-complete
fi

# Fallbacks for terminals that emit alternate Home/End sequences.
bindkey -- $'\e[H' beginning-of-line
bindkey -- $'\eOH' beginning-of-line
bindkey -- $'\e[1~' beginning-of-line
bindkey -- $'\e[7~' beginning-of-line
bindkey -- $'\e[F' end-of-line
bindkey -- $'\eOF' end-of-line
bindkey -- $'\e[4~' end-of-line
bindkey -- $'\e[8~' end-of-line

# completion - optimized for speed
autoload -Uz compinit add-zsh-hook
ZCD=~/.zcompdump

# Fast completion: only regenerate if missing
if [[ ! -f $ZCD ]]; then
  compinit
  zcompile $ZCD
else
  compinit -C
fi

# Minimal completion styles for performance
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$_ZSH_CACHE_DIR/zcompcache"
zstyle ':completion:*:*:git:*' user-commands wt:'manage git worktrees'

_wt_complete() {
  local with_setup="$1"
  local subcmd_index=1
  local arg_index
  local subcmd
  local -a subcommands branches

  if (( ${words[(I)wt]} > 0 )); then
    subcmd_index=$(( ${words[(I)wt]} + 1 ))
  elif [[ ${words[1]:-} == wt || ${words[1]:-} == git-wt || ${words[1]:-} == git ]]; then
    subcmd_index=2
  fi

  if [[ "$with_setup" == "1" ]]; then
    subcommands=(add rm ls prune setup)
  else
    subcommands=(add rm ls prune)
  fi

  subcmd="${words[subcmd_index]:-}"
  arg_index=$((subcmd_index + 1))

  if (( CURRENT == subcmd_index )); then
    compadd -- "${subcommands[@]}"
    return
  fi

  if [[ "$subcmd" == rm ]] && (( CURRENT >= arg_index )); then
    branches=("${(@f)$(command git worktree list --porcelain 2>/dev/null | awk '$1 == "branch" { sub("^refs/heads/", "", $2); print $2 }')}")
    (( ${#branches[@]} > 0 )) && compadd -- "${branches[@]}"
    return
  fi
}

_wt() {
  _wt_complete 1
}

_git-wt() {
  _wt_complete 0
}

compdef _wt wt
compdef _git-wt git-wt

# Defer heavy interactive features until first prompt for faster shell startup
if [[ -o interactive ]]; then
  _deferred_shell_init() {
    # mise version manager
    if command -v mise > /dev/null 2>&1; then
      eval "$(mise activate zsh)"
    fi

    # zoxide smart cd
    if command -v zoxide > /dev/null 2>&1; then
      eval "$(zoxide init zsh)"
      alias cd='z'
    fi

    # starship prompt
    if command -v starship > /dev/null 2>&1; then
      eval "$(starship init zsh)"
    fi

    # Package manager plugins (Linux then macOS paths)
    # zsh-autosuggestions
    if [[ -r "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
      source "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    elif [[ -r "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
      source "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
    elif [[ -r "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
      source "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi

    # zsh-syntax-highlighting (load after other interactive setup)
    if [[ -r "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
      source "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    elif [[ -r "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
      source "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    elif [[ -r "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
      source "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    fi

    add-zsh-hook -d precmd _deferred_shell_init
    unfunction _deferred_shell_init
  }

  add-zsh-hook precmd _deferred_shell_init
fi

# fzf integration with caching
FZF_ZSH_CACHE="$HOME/.cache/fzf-zsh"
if [[ ! -f "$FZF_ZSH_CACHE" ]] && command -v fzf > /dev/null 2>&1; then
  fzf --zsh > "$FZF_ZSH_CACHE"
fi
[[ -r "$FZF_ZSH_CACHE" ]] && source "$FZF_ZSH_CACHE"
