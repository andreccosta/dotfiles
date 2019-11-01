# path to oh-my-zsh install
ZSH=$HOME/.oh-my-zsh

# set default user to hide user@hos
DEFAULT_USER=`whoami`

# set theme
ZSH_THEME="spaceship"

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

# spacehsip customization
SPACESHIP_PROMPT_ORDER=(
  user          # Username section
  dir           # Current directory section
  host          # Hostname section
  git           # Git section (git_branch + git_status)
  hg            # Mercurial section (hg_branch  + hg_status)
  exec_time     # Execution time
  line_sep      # Line break
  vi_mode       # Vi-mode indicator
  jobs          # Background jobs indicator
  exit_code     # Exit code section
  char          # Prompt character
)
SPACESHIP_USER_SHOW=always
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_CHAR_SYMBOL="❯"
SPACESHIP_CHAR_SUFFIX=" "
SPACESHIP_PROMPT_SEPARATE_LINE=false
