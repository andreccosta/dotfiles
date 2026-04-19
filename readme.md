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

## Re-stow after changes

```console
$ ./dot restow
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
