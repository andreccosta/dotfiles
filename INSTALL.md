# Dotfiles Installation

This repository contains personal dotfiles optimized for fast zsh startup times.

## Quick Setup

Clone and run the installation script:

```bash
git clone https://github.com/andreccosta/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Or use the Makefile:

```bash
git clone https://github.com/andreccosta/dotfiles.git ~/dotfiles
cd ~/dotfiles
make install
```

## What the installer does

1. **Checks dependencies** - Ensures git is available
2. **Creates symlinks** - Links dotfiles to your home directory using the Makefile
3. **Sets up zsh** - Makes zsh the default shell if available

## Manual Setup

If you prefer manual setup:

1. Clone the repository
2. Run `make dotfiles` to create symlinks
3. Set zsh as default shell: `chsh -s $(which zsh)`
4. Restart your terminal

## Required Tools

The installer sets up the shell configuration, but you'll need to install these tools separately using your package manager:

### macOS (Homebrew)

```bash
brew install zsh-autosuggestions zsh-syntax-highlighting zoxide fzf vivid starship mise
```

### Linux

```bash
# Debian/Ubuntu
sudo apt install zsh-autosuggestions zsh-syntax-highlighting fzf

# Fedora
sudo dnf install zsh-autosuggestions zsh-syntax-highlighting fzf

# Arch Linux
sudo pacman -S zsh-autosuggestions zsh-syntax-highlighting fzf
```

Note: Some tools (zoxide, vivid, starship, mise) may not be available in all package managers and might need alternative installation methods.

## Plugin Configuration

Plugins are loaded directly from standard package manager installation paths (no plugin manager needed):

- `zsh-autosuggestions` - Command suggestions
- `zsh-syntax-highlighting` - Syntax highlighting  
- `zoxide` - Smart cd replacement
- `mise` - Runtime version manager
- `fzf` - Fuzzy finder
- `starship` - Customizable prompt

See `.zshrc` for the loading configuration.
