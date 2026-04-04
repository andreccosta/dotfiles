#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.config/opencode"

mkdir -p "$TARGET_DIR"

ln -snf "$SCRIPT_DIR/commands" "$TARGET_DIR"
ln -snf "$SCRIPT_DIR/plugins" "$TARGET_DIR"
ln -snf "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR"
ln -snf "$SCRIPT_DIR/opencode.json" "$TARGET_DIR"
ln -snf "$SCRIPT_DIR/tui.json" "$TARGET_DIR"
