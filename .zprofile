# env - colors and locale
export CLICOLOR=1
export LANG=en_US.UTF-8
export LSCOLORS="exfxcxdxbxegedabagacad"
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:/opt/homebrew/bin:$PATH"

# Use vivid for modern LS_COLORS themes - change 'tokyonight-night' to any theme: vivid themes
if command -v vivid >/dev/null 2>&1; then
  export LS_COLORS="$(vivid generate tokyonight-night)"
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
