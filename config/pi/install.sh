#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.pi/agent"
SOURCE_DIR="$SCRIPT_DIR/agent/extensions"
LINK_PATH="$TARGET_DIR/extensions"

mkdir -p "$TARGET_DIR"

if [ -e "$LINK_PATH" ] && [ ! -L "$LINK_PATH" ]; then
  printf 'Error: %s exists and is not a symlink\n' "$LINK_PATH" >&2
  exit 1
fi

ln -snf "$SOURCE_DIR" "$LINK_PATH"
ln -snf "$SCRIPT_DIR/agent/AGENTS.md" "$TARGET_DIR"
