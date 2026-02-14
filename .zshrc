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

# Package manager plugins (Linux then macOS paths)
# zsh-autosuggestions
if [[ -r "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
elif [[ -r "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# zsh-syntax-highlighting
if [[ -r "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [[ -r "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# pulumi
[[ -d "$HOME/.pulumi/bin" ]] && export PATH="$PATH:$HOME/.pulumi/bin"

# mise version manager
if command -v mise > /dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# starship prompt
if command -v starship > /dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# zoxide smart cd
if command -v zoxide > /dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd='z'
fi

# fzf integration with caching
FZF_ZSH_CACHE="$HOME/.cache/fzf-zsh"
if [[ ! -f "$FZF_ZSH_CACHE" ]] && command -v fzf > /dev/null 2>&1; then
  fzf --zsh > "$FZF_ZSH_CACHE"
fi
[[ -r "$FZF_ZSH_CACHE" ]] && source "$FZF_ZSH_CACHE"
