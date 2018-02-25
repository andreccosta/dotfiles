# path to oh-my-zsh install
ZSH=$HOME/.oh-my-zsh

# set default user to hide user@hos
DEFAULT_USER=`whoami`

# set theme
ZSH_THEME="agnoster"

# set plugins (the less the better)
plugins=(git osx)

source $ZSH/oh-my-zsh.sh

# window title same as tab
ZSH_THEME_TERM_TITLE_IDLE=$ZSH_THEME_TERM_TAB_TITLE_IDLE

# export default lang
#export LANG=en_US.UTF-8

# golang
export GOPATH="$HOME/code/go"
export PATH=$PATH:$GOPATH/bin
