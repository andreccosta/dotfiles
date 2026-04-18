# Dotfiles Installation

This repository uses GNU Stow to manage symlinks for shell files and application config. Common cross-system files live in the `home` Stow package, and platform-specific packages are only installed on matching systems.

## Quick Setup

### macOS

```bash
brew install git stow
mkdir -p ~/code/src/github.com/andreccosta
git clone https://github.com/andreccosta/dotfiles.git ~/code/src/github.com/andreccosta/dotfiles
cd ~/code/src/github.com/andreccosta/dotfiles
./install.sh
./dot macos
```

### Linux

```bash
mkdir -p ~/code/src/github.com/andreccosta
git clone https://github.com/andreccosta/dotfiles.git ~/code/src/github.com/andreccosta/dotfiles
cd ~/code/src/github.com/andreccosta/dotfiles
./install.sh
```

Or run Stow through the repo helper directly:

```bash
mkdir -p ~/code/src/github.com/andreccosta
git clone https://github.com/andreccosta/dotfiles.git ~/code/src/github.com/andreccosta/dotfiles
cd ~/code/src/github.com/andreccosta/dotfiles
./dot install
```

## Requirements

- `git`
- `stow`

### macOS

```bash
brew install stow
```

### Linux

```bash
# Debian/Ubuntu
sudo apt install stow

# Fedora
sudo dnf install stow

# Arch Linux
sudo pacman -S stow
```

## What the installer does

1. Ensures `git` and `stow` are installed
2. Stows the default package set from `stow/` into `$HOME`
3. Makes `zsh` the default shell if available

## Stow commands

Install the default package set:

```bash
./dot install
```

Install only specific packages:

```bash
./dot install home
./dot install home nvim
```

Re-stow after making changes:

```bash
./dot restow
```

Update system packages and mise tools:

```bash
./dot update
```

- macOS: runs `brew update && brew upgrade`, then `mise up`
- Linux: runs `paru -Syu` if available, then `mise up`

Install macOS Brewfile packages and apply macOS defaults:

```bash
./dot macos
```

## Notes

- `dot` is a repo-local bootstrap script. Run it from the root of this repository as `./dot ...`.
- Existing files in `$HOME` can conflict with Stow-managed symlinks. Move or back them up first if Stow reports a conflict.
- Windows setup is still handled separately by `win/install.ps1`.
- `./dot macos` runs `brew bundle --file mac/Brewfile` and `mac/set_defaults.sh`.
- macOS system setup is still separate from Stow-managed symlinks.
