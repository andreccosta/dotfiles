# set default user to hide user@hos
DEFAULT_USER=`whoami`

# export default lang
export LANG=en_US.UTF-8

## key bindings

# bind home/end
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line

# ctrl+arrows
bindkey "\e[1;5C" forward-word
bindkey "\e[1;5D" backward-word
# urxvt
bindkey "\eOc" forward-word
bindkey "\eOd" backward-word

# ctrl+delete
bindkey "\e[3;5~" kill-word
# urxvt
bindkey "\e[3^" kill-word

# ctrl+backspace
bindkey '^H' backward-kill-word

# ctrl+shift+delete
bindkey "\e[3;6~" kill-line
# urxvt
bindkey "\e[3@" kill-line

# more key binds
bindkey '^[3~' kill-word # option-backspace
bindkey '^[[1;3D' backward-word # option-left
bindkey '^[[1;3C' forward-word # option-right
bindkey '^[[1;9D' beginning-of-line # cmd-left
bindkey '^[[1;9C' end-of-line # cmd-right

# edit command line
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line

# options
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt AUTO_PUSHD	 # push old dir to stack
setopt CDABLE_VARS	 # expand (allow 'cd -2/tmp')
setopt SHARE_HISTORY     # share history between sessions
setopt HIST_IGNORE_SPACE # ignore history for commands starting with space

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

# asdf
[ -f $HOME/.asdf/asdf.sh ] && source $HOME/.asdf/asdf.sh
[ -f $HOMEBREW_PREFIX/opt/asdf/libexec/asdf.sh ] && source $HOMEBREW_PREFIX/opt/asdf/libexec/asdf.sh

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# add Pulumi to the PATH
[ -d $HOME/.pulumi/bin ] && export PATH=$PATH:$HOME/.pulumi/bin

# starship
eval "$(starship init zsh)"

# z
eval "$(zoxide init --cmd cd zsh)"
