#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

setup_zsh() {
  if ! command_exists zsh; then
    print_warning "zsh not found. Please install zsh first."
    return
  fi

  if [ "$SHELL" != "$(command -v zsh)" ]; then
    print_status "Setting zsh as default shell..."
    chsh -s "$(command -v zsh)"
    print_status "Zsh set as default shell. Please log out and log back in to apply changes."
  else
    print_status "Zsh is already the default shell"
  fi
}

main() {
  print_status "Starting dotfiles installation..."

  if ! command_exists git; then
    print_error "Git is required but not installed. Please install git first."
    exit 1
  fi

  if ! command_exists stow; then
    print_error "GNU Stow is required. Install it first and rerun this script."
    exit 1
  fi

  local dotfiles_dir
  dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$dotfiles_dir"

  print_status "Stowing dotfiles packages..."
  ./dot install

  setup_zsh

  print_status "Dotfiles installation completed!"
}

main "$@"
