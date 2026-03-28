#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.config/ghostty"

mkdir -p "$TARGET_DIR"

ln -snf "$SCRIPT_DIR/config" "$TARGET_DIR"
ln -snf "$SCRIPT_DIR/shaders" "$TARGET_DIR"
