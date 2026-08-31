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

## CLI workflow

The dotfiles also install a small `hwt` command for the non-modal workflow:

```sh
hwt create <branch> [base]
hwt open [branch-or-path]
hwt remove [branch-or-path]
```

`hwt` delegates creation/switching/removal to `wt`, then opens the selected checkout with `herdr worktree open` so Herdr keeps native worktree grouping/provenance. When run outside Herdr, it starts/attaches Herdr like `hm`.

## Actions

- `Worktree via Worktrunk: create` — prompts for a branch/base ref, runs `wt switch --create`, then opens the new worktree in Herdr.
- `Worktree via Worktrunk: open` — lists `wt list` results and opens the selected worktree in Herdr.
- `Worktree via Worktrunk: remove current` — runs `wt remove` for the current linked worktree and closes the Herdr workspace.

## Keybindings

The dotfiles Herdr config disables Herdr's built-in `new_worktree` / `remove_worktree` bindings and maps plugin actions instead:

- `prefix+shift+g` — create via Worktrunk
- `prefix+shift+o` — open via Worktrunk
- `prefix+alt+r` — remove via Worktrunk
