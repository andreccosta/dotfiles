# performance optimizations
ZSH_DISABLE_COMPFIX=true
_ZSH_CACHE_DIR="$HOME/.zsh_cache"
mkdir -p "$_ZSH_CACHE_DIR"

# lazy loading infrastructure
_lazy_load() {
  local cmd=$1
  local init_cmd=$2
  eval "$cmd() { unset -f $cmd; $init_cmd; $cmd \"\$@\"; }"
}

# history
HISTFILE=~/.zsh_history
HISTSIZE=10000000
SAVEHIST=10000000

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

# key bindings
typeset -g -A key

key[Home]="${terminfo[khome]}"
key[End]="${terminfo[kend]}"
key[Insert]="${terminfo[kich1]}"
key[Backspace]="${terminfo[kbs]}"
key[Delete]="${terminfo[kdch1]}"
key[Up]="${terminfo[kcuu1]}"
key[Down]="${terminfo[kcud1]}"
key[Left]="${terminfo[kcub1]}"
key[Right]="${terminfo[kcuf1]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[Shift-Tab]="${terminfo[kcbt]}"

# setup key accordingly
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

# completion
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
	compinit -u;
else
	compinit -u -C;
fi;

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$_ZSH_CACHE_DIR/zcompcache"

# lazy load auto suggestions & syntax highlighting
_load_autosuggestions() {
  if [[ -n "$HOMEBREW_PREFIX" ]]; then
    source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  elif [[ -d /usr/share/zsh/plugins ]]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  fi
}

_load_syntax_highlighting() {
  if [[ -n "$HOMEBREW_PREFIX" ]]; then
    source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  elif [[ -d /usr/share/zsh/plugins ]]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  fi
}

# defer loading until first prompt via hook
_lazy_plugin_precmd() {
  if [[ -z "$_AUTOSUGGESTIONS_LOADED" ]]; then
    _load_autosuggestions
    _AUTOSUGGESTIONS_LOADED=1
  fi
  if [[ -z "$_SYNTAX_HIGHLIGHTING_LOADED" ]]; then
    _load_syntax_highlighting
    _SYNTAX_HIGHLIGHTING_LOADED=1
  fi
  if [[ -n "$_AUTOSUGGESTIONS_LOADED" && -n "$_SYNTAX_HIGHLIGHTING_LOADED" ]]; then
    add-zsh-hook -d precmd _lazy_plugin_precmd
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _lazy_plugin_precmd

# lazy load mise
if command -v mise > /dev/null 2>&1; then
  _lazy_load mise 'source <(mise activate zsh)'
fi

# lazy load fzf
if command -v fzf > /dev/null 2>&1; then
  _lazy_load fzf 'source <(fzf --zsh)'
fi

# pulumi
[[ -d "$HOME/.pulumi/bin" ]] && export PATH="$PATH:$HOME/.pulumi/bin"

# starship
eval "$(starship init zsh)"

# lazy load zoxide
if command -v zoxide > /dev/null 2>&1; then
  _lazy_load z 'eval "$(zoxide init zsh)"'
  alias cd='z'
fi
