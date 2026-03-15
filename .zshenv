# shared environment (loaded by every zsh invocation)
export LANG=en_US.UTF-8

# PATH handling (idempotent)
typeset -U path PATH

export GOPATH="$HOME/code/go"

[[ -d "$HOME/bin" ]] && path=("$HOME/bin" $path)
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
[[ -d "$GOPATH/bin" ]] && path=("$GOPATH/bin" $path)
[[ -d "$HOME/.cargo/bin" ]] && path=("$HOME/.cargo/bin" $path)

export PATH

# optional local exports
[[ -r ~/.exports ]] && source ~/.exports
