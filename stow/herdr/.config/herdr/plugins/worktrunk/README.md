# Herdr Worktrunk plugin

Tiny local Herdr plugin that delegates worktree management to [`wt`](https://worktrunk.dev/).

It is intentionally just a TOML manifest plus a shell script, so it can be tracked and installed from this dotfiles repository without a build step.

## Install

After stowing the `herdr` package, link the plugin into Herdr:

```sh
herdr plugin link ~/.config/herdr/plugins/worktrunk --enabled
herdr server reload-config
```

`./dot install` links the plugin automatically when the `herdr` package is part of the install and the `herdr` executable is available.

When developing directly from this repository, you can also link the repository path:

```sh
herdr plugin link ./stow/herdr/.config/herdr/plugins/worktrunk --enabled
```

## Actions

- `Worktrunk: create worktree` — prompts for a branch/base ref, runs `wt switch --create`, then opens the new worktree in Herdr.
- `Worktrunk: open worktree` — lists `wt list` results and opens the selected worktree in Herdr.
- `Worktrunk: remove current worktree` — runs `wt remove` for the current linked worktree and closes the Herdr workspace.

## Keybindings

The dotfiles Herdr config disables Herdr's built-in `new_worktree` / `remove_worktree` bindings and maps plugin actions instead:

- `prefix+shift+g` — create via Worktrunk
- `prefix+shift+o` — open via Worktrunk
- `prefix+alt+r` — remove via Worktrunk
