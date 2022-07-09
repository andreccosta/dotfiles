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


# edit command line
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^X^E" edit-command-line

# starship
eval "$(starship init zsh)"

# options
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt AUTO_PUSHD	# push old dir to stack
setopt CDABLE_VARS	# expand (allow 'cd -2/tmp')
setopt histignorespace  # ignore history for commands starting with space

# syntax highlighting
[ -d "/usr/share/zsh-syntax-highlighting" ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -d "/usr/local/share/zsh-syntax-highlighting" ] && source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -d "/usr/share/zsh-autosuggestions" ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -d "/usr/local/share/zsh-autosuggestions" ] && source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# load the shell dotfiles, and then some:
# * ~/.extra can be used for other settings you dont want to commit.
for file in ~/.{aliases,functions,prompt,osx,extra,exports}; do
	if [[ -r "$file" ]] && [[ -f "$file" ]]; then
		# shellcheck source=/dev/null
		source "$file"
	fi
done
unset file

if [[ -f $HOME/.zshrc.local ]]; then
  source $HOME/.zshrc.local
fi

# keychain
if which keychain > /dev/null; then
	[[ -f $HOME/.ssh/id_rsa ]] && /usr/bin/keychain -q --nogui $HOME/.ssh/id_rsa
	[[ -f $HOME/.ssh/id_ed25519 ]] && /usr/bin/keychain -q --nogui $HOME/.ssh/id_ed25519

	source $HOME/.keychain/$HOST-sh
fi

# rbenv
[[ -d $HOME/.rbenv/bin ]] && export PATH="$HOME/.rbenv/bin:$PATH"
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi
[[ -d $HOME/.rbenv/plugins/ruby-build/bin ]] && export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"

# nvm
[[ -d $HOME/.nvm ]] && export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# z
[ -s ~/code/src/github.com/andreccosta/dotfiles/z.sh ] && source ~/code/src/github.com/andreccosta/dotfiles/z.sh

# go version manager
[[ -s "/home/acosta/.gvm/scripts/gvm" ]] && source "/home/acosta/.gvm/scripts/gvm"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
