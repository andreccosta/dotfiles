# Dotfiles Installation

This repository uses GNU Stow to manage symlinks for shell files and application config.

## Quick Setup

Clone the repo and run the installer:

```bash
git clone https://github.com/andreccosta/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Or run Stow through the repo helper directly:

```bash
git clone https://github.com/andreccosta/dotfiles.git ~/dotfiles
cd ~/dotfiles
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
3. Symlinks `./dot` to `~/bin/dot`
4. Makes `zsh` the default shell if available

## Stow commands

Install the default package set:

```bash
./dot install
```

Re-stow after making changes:

```bash
./dot restow
```

Update Homebrew packages and mise tools:

```bash
./dot update
```

## Notes

- Existing files in `$HOME` can conflict with Stow-managed symlinks. Move or back them up first if Stow reports a conflict.
- Windows setup is still handled separately by `win/install.ps1`.
- macOS system setup scripts like `mac/set_defaults.sh` are still separate from Stow.
