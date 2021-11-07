# path to oh-my-zsh install
#ZSH=$HOME/.oh-my-zsh

# set default user to hide user@hos
DEFAULT_USER=`whoami`

# set theme
#ZSH_THEME="spaceship"

# set plugins (the less the better)
#plugins=(docker git osx zsh-syntax-highlighting zsh-autosuggestions)

#source $ZSH/oh-my-zsh.sh

# window title same as tab
ZSH_THEME_TERM_TITLE_IDLE=$ZSH_THEME_TERM_TAB_TITLE_IDLE

# export default lang
export LANG=en_US.UTF-8

# golang
export GOPATH="$HOME/code"
export PATH=$PATH:$GOPATH/bin

# spacehsip customization
#SPACESHIP_PROMPT_ORDER=(
#  user          # Username section
#  dir           # Current directory section
#  host          # Hostname section
#  git           # Git section (git_branch + git_status)
#  hg            # Mercurial section (hg_branch  + hg_status)
#  exec_time     # Execution time
#  line_sep      # Line break
#  vi_mode       # Vi-mode indicator
#  jobs          # Background jobs indicator
#  exit_code     # Exit code section
#  char          # Prompt character
#)
#SPACESHIP_USER_SHOW=always
#SPACESHIP_PROMPT_ADD_NEWLINE=false
#SPACESHIP_CHAR_SYMBOL="❯"
#SPACESHIP_CHAR_SUFFIX=" "
#SPACESHIP_PROMPT_SEPARATE_LINE=false

# bind home/end
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line

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
for file in ~/.{aliases,functions,path,prompt,osx,extra,exports}; do
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
	if [[ -r $HOME/.ssh/id_rsa ]]; then
		/usr/bin/keychain -q --nogui $HOME/.ssh/id_rsa
	fi
	
	if [[ -r $HOME/.ssh/id_ed25519 ]]; then
		/usr/bin/keychain -q --nogui $HOME/.ssh/id_ed25519
	fi
	
	source $HOME/.keychain/$HOST-sh
fi

# rbenv
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
