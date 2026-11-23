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

Install the repo-local ShellCheck version and run the tests with mise:

```console
$ mise install
$ mise run test
```

Tests also require `file` and GNU Stow installed on the system. `./test.sh`
still works directly when these dependencies and ShellCheck are on `PATH`.

## Rex

The `rex` package tracks `~/.config/rex/init.lua`. It swaps the default shortcuts:

- **Cmd+N**: new session
- **Cmd+Shift+N**: new app window

Install and reload it with:

```sh
./dot install rex
rex config check
rex config reload
```

### Resuming agents after a server restart

Rex restores sessions, windows and blocks (same IDs, working directories) but
not the programs in them. `~/.config/rex/resume.zsh` (sourced from `.zshrc`)
fills the gap for `claude` and `pi`: in a block's outermost shell, they run
through wrappers that keep a per-block record of the conversation under
`~/.local/state/rex-resume/`, deleted when the agent exits normally. When a
restored block's shell starts with a record left, the resume command
(`claude --resume <id>` or `pi --session <file>`) is typed at the prompt for
you to run.

Conversations are recorded once saved, after their first reply. Pi records
through `stow/pi/.pi/agent/extensions/rex-resume.ts`. Claude needs this hook
under both `SessionStart` and `Stop` in `~/.claude/settings.json`, which isn't
tracked here:

```json
{ "hooks": [{ "type": "command", "command": "sh ~/.config/rex/claude-resume-hook.sh" }] }
```

Agents started outside the wrappers (`command claude`, a full path, nested in
another agent or in a multiplexer inside the block) aren't recorded. Startup
flags such as `--model` aren't kept.

## Agent skills

Shared agent skills live in the `agents` Stow package. See [stow/agents/README.md](stow/agents/README.md) for the `second-opinion` workflow.
