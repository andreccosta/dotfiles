# performance optimizations
ZSH_DISABLE_COMPFIX=true
_ZSH_CACHE_DIR="$HOME/.zsh_cache"
mkdir -p "$_ZSH_CACHE_DIR"

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

# key bindings - optimized for speed
typeset -g -A key

# Only setup if terminfo is available
if [[ -n "$terminfo" ]]; then
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
fi

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

# antidote plugin manager - load synchronously for reliability
if [[ -f ~/.antidote/antidote.zsh ]]; then
  source ~/.antidote/antidote.zsh
  antidote load ~/code/src/github.com/andreccosta/dotfiles/.zsh_plugins.txt
fi

# mise and fzf are loaded by antidote

# pulumi
[[ -d "$HOME/.pulumi/bin" ]] && export PATH="$PATH:$HOME/.pulumi/bin"

# starship - load immediately for prompt visibility
if [[ -f ~/.config/starship/init.zsh ]]; then
  source ~/.config/starship/init.zsh
fi

# zoxide is now loaded by antidote
alias cd='z'

# fzf integration - conditional load for reliability
if [[ -n "$PS1" ]] && command -v fzf > /dev/null 2>&1; then
  source <(fzf --zsh)
fi
