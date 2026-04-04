#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.agents"

mkdir -p "$TARGET_DIR"

ln -snf "$SCRIPT_DIR/skills" "$TARGET_DIR/"
