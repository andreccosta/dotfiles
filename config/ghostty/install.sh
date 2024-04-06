#!/usr/bin/env bash

set -euo pipefail

mkdir -p ~/.config/ghostty
ln -snf "$PWD"/config ~/.config/ghostty/config
