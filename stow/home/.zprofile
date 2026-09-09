# homebrew
if [[ "$OSTYPE" == darwin* ]]; then
  for brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x $brew ]] && { _zsh_cached_init "$brew" shellenv; break }
  done
  unset brew
  [[ -d "/opt/homebrew/opt/coreutils/libexec/gnubin" ]] && path=("/opt/homebrew/opt/coreutils/libexec/gnubin" $path)
  [[ -d "/opt/homebrew/opt/ncurses/bin" ]] && path=("/opt/homebrew/opt/ncurses/bin" $path)
fi


# added by OrbStack
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
