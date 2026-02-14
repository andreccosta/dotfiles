# env - colors and locale
export CLICOLOR=1
export LANG=en_US.UTF-8
export LSCOLORS="exfxcxdxbxegedabagacad"
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:/opt/homebrew/bin:$PATH"

# Use vivid for modern LS_COLORS themes - cached for performance
if command -v vivid >/dev/null 2>&1; then
  VIVID_CACHE="$HOME/.cache/ls_colors"
  if [[ ! -f "$VIVID_CACHE" ]]; then
    mkdir -p "$HOME/.cache"
    vivid generate tokyonight-night > "$VIVID_CACHE"
  fi
  export LS_COLORS="$(cat "$VIVID_CACHE")"
fi

# load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{aliases,functions,path,linux,osx,extra,exports}; do
	if [[ -r "$file" ]] && [[ -f "$file" ]]; then
		# shellcheck source=/dev/null
		source "$file"
	fi
done
unset file

# cargo
if [[ -r ~/.cargo/env ]]; then
  source ~/.cargo/env
fi

# added by OrbStack
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
