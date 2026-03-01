# shared environment (loaded by every zsh invocation)
export LANG=en_US.UTF-8

# PATH handling (idempotent)
typeset -U path PATH

export GOPATH="$HOME/code/go"

[[ -d "$HOME/bin" ]] && path=("$HOME/bin" $path)
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
[[ -d "$GOPATH/bin" ]] && path=("$GOPATH/bin" $path)
[[ -d "$HOME/.cargo/bin" ]] && path=("$HOME/.cargo/bin" $path)
[[ -d "$HOME/.pulumi/bin" ]] && path=("$HOME/.pulumi/bin" $path)

if [[ "$OSTYPE" == darwin* ]]; then
  [[ -d "/opt/homebrew/opt/coreutils/libexec/gnubin" ]] && path=("/opt/homebrew/opt/coreutils/libexec/gnubin" $path)
  [[ -d "/opt/homebrew/bin" ]] && path=("/opt/homebrew/bin" $path)
  [[ -d "/opt/homebrew/opt/ncurses/bin" ]] && path=("/opt/homebrew/opt/ncurses/bin" $path)
fi

export PATH

# optional local exports
[[ -r ~/.exports && -f ~/.exports ]] && source ~/.exports

# cargo
[[ -r ~/.cargo/env ]] && source ~/.cargo/env
