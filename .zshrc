# path to oh-my-zsh install
ZSH=$HOME/.oh-my-zsh

# set default user to hide user@hos
DEFAULT_USER=`whoami`

# set theme
ZSH_THEME="agnoster"

# set plugins (the less the better)
plugins=(git osx)

source $ZSH/oh-my-zsh.sh

# export default lang
#export LANG=en_US.UTF-8

export PATH="$HOME/.yarn/bin:$PATH"
export GOPATH="$HOME/code/go"
export PATH=$PATH:$GOPATH/bin
