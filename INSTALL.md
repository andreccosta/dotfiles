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
3. Configures git commit signing for this machine and checks the GitHub SSH setup (see [Git signing & SSH on a new machine](#git-signing--ssh-on-a-new-machine))
4. Makes `zsh` the default shell if available

When installing the `home` package, `./dot install` also rebuilds bat's theme cache if `bat` is on PATH. Machines without bat skip this step; after installing it, rerun `./dot install home` or run `bat cache --build`.

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

Sync after making changes:

```bash
./dot install
```

Update system packages and mise tools:

```bash
./dot update
```

- macOS: runs `brew update && brew upgrade`, then `mise up`
- Linux (Debian/Ubuntu): runs `sudo apt-get update && sudo apt-get upgrade -y`, then `mise up`
- Linux (Arch): runs `paru -Syu` or `yay -Syu` if available, then `mise up`

Install macOS Brewfile packages and apply macOS defaults:

```bash
./dot macos
```

## Herdr Worktrunk plugin

The local Herdr plugin is stowed with the `herdr` package and linked automatically by `./dot install` when `herdr` is available. To link it manually:

```bash
herdr plugin link ~/.config/herdr/plugins/worktrunk --enabled
herdr server reload-config
```

The `home` package also installs `hwt`, a CLI-first Worktrunk workflow:

```bash
hwt create <branch> [base]
hwt switch [branch-or-path]
hwt remove [branch-or-path]
```

Use `hm` to open the current checkout in Herdr, `hwt` to let Worktrunk manage a worktree before opening it in Herdr, and `hwta` to create a Worktrunk worktree and start an OpenCode agent there. `hwt open` remains available as an alias for `hwt switch`.

## Git signing & SSH on a new machine

Commits and tags are signed with SSH keys. The shared `stow/home/.gitconfig` uses the 1Password **Github Signing Key**, and per-machine choices go in the untracked `~/.gitconfig.local`. That file is included last, so it overrides the shared config.

`./dot install` (when installing the `home` package) works out the signing setup for each machine:

| Machine | What `./dot install` does | Signs with |
| --- | --- | --- |
| 1Password app installed and SSH agent running | sets `gpg.ssh.program` to `op-ssh-sign` | 1Password signing key |
| 1Password installed but SSH agent off | warns; enable it in 1Password > Settings > Developer | - |
| `~/.gitconfig.local` sets `user.signingkey` | keeps it | that key file |
| No 1Password, nothing configured, run from a terminal | asks once: pick a key in `~/.ssh`, generate a dedicated one, use a forwarded agent, or skip | your choice |
| No 1Password, nothing configured, no terminal | prints the manual commands below | - |

A saved `gpg.ssh.program` path that no longer exists is removed.

### Manual setup

On a machine without 1Password, choose one of:

```bash
# Key file on this machine. Works unattended (e.g. coding agents), so use a
# dedicated key without a passphrase that you can revoke separately.
git config --file ~/.gitconfig.local user.signingkey ~/.ssh/<private_key>

# Forwarded 1Password agent. Only works while connected with `ssh -A`
# (or `ForwardAgent yes`); approvals happen on the local machine.
git config --file ~/.gitconfig.local dotfiles.signing agent
```

For a key file, point `user.signingkey` at the **private** key, so signing doesn't need an agent. Then:

1. Add its public key on GitHub as a **Signing key** (Settings > SSH and GPG keys).
2. Add it to `stow/home/.config/git/allowed_signers` so `git log --show-signature` can verify it locally:
   `<email> ssh-ed25519 AAAA...`

### SSH authentication with 1Password

`./dot install` only checks these and prints what's missing. It never edits `~/.ssh`.

```sshconfig
# ~/.ssh/config: use the 1Password agent
Host *
	IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"   # macOS
	# IdentityAgent ~/.1password/agent.sock                                             # Linux

# Optional: only offer the GitHub auth key to GitHub. The .pub file is
# exported from 1Password (Github Auth Key > public key).
Host github.com
	IdentityFile ~/.ssh/op_github_auth.pub
	IdentitiesOnly yes
```

Add GitHub's host keys and compare them against [GitHub's published fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints):

```bash
ssh-keyscan github.com >> ~/.ssh/known_hosts
ssh-keygen -lf ~/.ssh/known_hosts
```

To forward the agent to a remote machine, add `ForwardAgent yes` to that host's entry.

### Verify

```bash
ssh -T git@github.com
git commit --allow-empty -m test && git log --show-signature -1
```

## Notes

- `dot` is a repo-local bootstrap script. Run it from the root of this repository as `./dot ...`.
- Existing files in `$HOME` can conflict with Stow-managed symlinks. Move or back them up first if Stow reports a conflict.
- `./dot macos` runs `brew bundle --file mac/Brewfile` and `mac/set_defaults.sh`.
- macOS system setup is still separate from Stow-managed symlinks.
