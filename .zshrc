# set default user to hide user@hos
DEFAULT_USER=`whoami`

# export default lang
export LANG=en_US.UTF-8

# golang
export GOPATH="$HOME/code"
export PATH=$PATH:$GOPATH/bin

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

# starship
eval "$(starship init zsh)"

# options
setopt AUTO_PUSHD	# push old dir to stack
setopt CDABLE_VARS	# expand (allow 'cd -2/tmp')

# syntax highlighting
[ -d "/usr/share/zsh-syntax-highlighting" ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -d "/usr/local/share/zsh-syntax-highlighting" ] && source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -d "/usr/share/zsh-autosuggestions" ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -d "/usr/local/share/zsh-autosuggestions" ] && source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you dont want to commit.
for file in ~/.{aliases,env,functions,path,prompt,osx,extra,exports}; do
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
[ -s /usr/local/etc/profile.d/z.sh ] && source /usr/local/etc/profile.d/z.sh
