# export
export CLICOLOR=1
export LANG=en_US.UTF-8
export LSCOLORS=exfxcxdxbxegedabagacad
export LS_COLORS="di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"

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

# completion
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# syntax highlighting
[ -d "/usr/share/zsh-syntax-highlighting" ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -d "/usr/local/share/zsh-syntax-highlighting" ] && source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# auto suggestions
[ -d "/usr/share/zsh-autosuggestions" ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -d "/usr/local/share/zsh-autosuggestions" ] && source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh

if [ -x "$(command -v brew)" ]; then
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

if [[ -f $HOME/.zshrc.local ]]; then
  source $HOME/.zshrc.local
fi

# keychain
if which keychain > /dev/null; then
  [[ -f $HOME/.ssh/id_rsa ]] && /usr/bin/keychain -q --nogui $HOME/.ssh/id_rsa
  [[ -f $HOME/.ssh/id_ed25519 ]] && /usr/bin/keychain -q --nogui $HOME/.ssh/id_ed25519

  source $HOME/.keychain/$HOST-sh
fi

# mise
eval "$(/opt/homebrew/bin/mise activate zsh)"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# add Pulumi to the PATH
[ -d $HOME/.pulumi/bin ] && export PATH=$PATH:$HOME/.pulumi/bin

# starship
eval "$(starship init zsh)"

# z
eval "$(zoxide init zsh)"
