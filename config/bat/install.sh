#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.config/bat"

mkdir -p "$TARGET_DIR"

ln -snf "$SCRIPT_DIR/themes" "$TARGET_DIR"
ln -snf "$SCRIPT_DIR/config" "$TARGET_DIR"
