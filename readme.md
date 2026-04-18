# dotfiles

This repo uses [GNU Stow](https://www.gnu.org/software/stow/) to manage symlinks into `$HOME`.

## Install

```console
$ ./install.sh
```

Or directly:

```console
$ ./dot install
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

## macOS bootstrap

```console
$ ./dot macos
```

## Test

```console
$ ./test.sh
```

Tests run with shellcheck.
