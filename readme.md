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

## Re-stow after changes

```console
$ ./dot restow
```

## Update tools

```console
$ ./dot update
```

## Test

```console
$ ./test.sh
```

Tests run with shellcheck.
