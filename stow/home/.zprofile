# homebrew
if [[ "$OSTYPE" == darwin* ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  [[ -d "/opt/homebrew/opt/coreutils/libexec/gnubin" ]] && path=("/opt/homebrew/opt/coreutils/libexec/gnubin" $path)
  [[ -d "/opt/homebrew/opt/ncurses/bin" ]] && path=("/opt/homebrew/opt/ncurses/bin" $path)
fi


# added by OrbStack
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
