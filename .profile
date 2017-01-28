# prompt with git branch
__git_ps1() {
        git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# show/hide dot files
show_dot() {
  defaults write com.apple.finder AppleShowAllFiles YES
  killall Finder
}

hide_dot() {
  defaults write com.apple.finder AppleShowAllFiles NO
  killall Finder
}

# show/hide desktop icons
show_icons() {
  defaults write com.apple.finder CreateDesktop true
  killall Finder
}

hide_icons() {
  defaults write com.apple.finder CreateDesktop false
  killall Finder
}

# WOL nas
alias wake_nas='wakeonlan 38:EA:A7:AB:F3:05'

# cd
alias ..='cd ..'
alias ...='cd ../..'

# curl
alias curl='curl -#'

# docker machine
alias dm_env='eval $(docker-machine env `docker-machine active`)'
alias dm_ip='docker-machine ip `docker-machine active`'
alias dm_stop='docker-machine stop `docker-machine active`'

function dm_start() {
  docker-machine start $1;
}

# git
alias gca="git commit -a"
alias gd="git diff"
alias gl="git log --pretty='format:%Cgreen%h%Creset %an - %s' --graph"
alias gst="git status"
alias gp="git push"
alias gpr="git push rebase"

# utils
alias ll='ls -lpah'

alias copy='pbcopy'
alias paste='pbpaste'
