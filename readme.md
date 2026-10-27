# dotfiles

This repo uses [GNU Stow](https://www.gnu.org/software/stow/) to manage symlinks into `$HOME`. Common cross-system files live in the `home` Stow package, and platform-specific packages are only installed on matching systems.

## Install

```console
$ mkdir -p ~/code/src/github.com/andreccosta
$ git clone https://github.com/andreccosta/dotfiles.git ~/code/src/github.com/andreccosta/dotfiles
$ cd ~/code/src/github.com/andreccosta/dotfiles
$ ./install.sh
```

Or directly:

```console
$ ./dot install
```

Install only specific packages when needed:

```console
$ ./dot install home
$ ./dot install home nvim
```

On macOS, then install Brewfile packages and apply defaults:

```console
$ ./dot macos
```

## Sync after changes

```console
$ ./dot install
```

## Update tools

```console
$ ./dot update
```

- macOS: `brew update && brew upgrade`, then `mise up`
- Linux (Debian/Ubuntu): `sudo apt-get update && sudo apt-get upgrade -y`, then `mise up`
- Linux (Arch): `paru -Syu` or `yay -Syu` if available, then `mise up`

## macOS bootstrap

```console
$ ./dot macos
```

## Test

```console
$ ./test.sh
```

Tests run with shellcheck.

## Agent reviews

`herdr-review` (in `stow/home/bin`) asks another coding agent to review your current changes in a new Herdr tab, waits for it, and prints only its findings. Run it yourself, or ask an agent for "a review from codex/claude/..." and it will use the `herdr-review` skill.

By default it uses a different harness than the caller (codex from claude, claude from anything else) and reviews the diff from the default branch's merge base to the working tree, including uncommitted and untracked files. The reviewer's tab stays open for follow-up questions.

```console
$ herdr-review                                        # default reviewer and model
$ herdr-review --agent claude --model opus            # pick the harness and model
$ herdr-review --worktree --focus "migrations"        # isolated worktree, committed changes only
$ herdr-review --base origin/release-1.2              # compare against another branch
$ herdr-review wait review-1a2b3c                     # keep waiting after a timeout or approval
$ herdr-review cleanup review-1a2b3c                  # close its tab and remove its files
```

See `herdr-review --help` for all options and exit codes.
