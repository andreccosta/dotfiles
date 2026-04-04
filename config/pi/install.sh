#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.pi/agent"

mkdir -p "$TARGET_DIR"

ln -snf "$SCRIPT_DIR/agent/extensions" "$TARGET_DIR/"
ln -snf "$SCRIPT_DIR/agent/prompts" "$TARGET_DIR/"
ln -snf "$SCRIPT_DIR/agent/themes" "$TARGET_DIR/"
ln -snf "$SCRIPT_DIR/agent/settings.json" "$TARGET_DIR/"
ln -snf "$SCRIPT_DIR/agent/models.json" "$TARGET_DIR/"
ln -snf "$SCRIPT_DIR/agent/package.json" "$TARGET_DIR/"
