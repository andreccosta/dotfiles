# load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{prompt,aliases,functions,path,osx,extra,exports}; do
	if [[ -r "$file" ]] && [[ -f "$file" ]]; then
		# shellcheck source=/dev/null
		source "$file"
	fi
done
unset file

# vscode
ln -sf $PWD/vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json

# fix curl alias
alias curl='noglob curl -#'

