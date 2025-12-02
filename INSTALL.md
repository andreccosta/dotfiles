# Dotfiles Installation

This repository contains personal dotfiles with antidote plugin manager for zsh.

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
3. **Installs antidote** - Clones the antidote plugin manager to `~/.antidote`
4. **Sets up zsh** - Makes zsh the default shell if available
5. **Configures plugins** - Antidote will automatically download plugins on first shell start

## Manual Setup

If you prefer manual setup:

1. Clone the repository
2. Run `make dotfiles` to create symlinks
3. Install antidote: `git clone https://github.com/getantidote/antidote.git ~/.antidote`
4. Set zsh as default shell: `chsh -s $(which zsh)`
5. Restart your terminal

## Required Tools

The installer sets up the shell configuration, but you'll need to install these tools separately:

- **mise** - Polyglot runtime version manager (https://mise.jdx.dev/)
- **fzf** - Command-line fuzzy finder (https://github.com/junegunn/fzf)
- **starship** - Customizable prompt (https://starship.rs/)

## Plugin Management

Plugins are managed through antidote in `.zsh_plugins.txt`:

- `zsh-users/zsh-completions` - Additional completions
- `zsh-users/zsh-autosuggestions` - Command suggestions
- `zsh-users/zsh-syntax-highlighting` - Syntax highlighting
- `wintermi/zsh-mise` - Mise integration
- `ajeetdsouza/zoxide` - Smart cd replacement

To add new plugins, edit `.zsh_plugins.txt` and restart your shell.