#!/bin/bash

# Dotfiles installation script
# This script sets up the dotfiles repository and installs dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install antidote if not present
install_antidote() {
    if [ ! -d "$HOME/.antidote" ]; then
        print_status "Installing antidote plugin manager..."
        git clone https://github.com/getantidote/antidote.git ~/.antidote
        print_status "Antidote installed successfully"
    else
        print_status "Antidote already installed, updating..."
        cd ~/.antidote && git pull origin main
    fi
}

# Setup zsh as default shell if available
setup_zsh() {
    if command_exists zsh; then
        if [ "$SHELL" != "$(which zsh)" ]; then
            print_status "Setting zsh as default shell..."
            chsh -s "$(which zsh)"
            print_status "Zsh set as default shell. Please log out and log back in to apply changes."
        else
            print_status "Zsh is already the default shell"
        fi
    else
        print_warning "Zsh not found. Please install zsh first."
    fi
}

# Install common dependencies
install_dependencies() {
    print_status "Checking for common dependencies..."
    
    # Check for git
    if ! command_exists git; then
        print_error "Git is required but not installed. Please install git first."
        exit 1
    fi
    
    # Check for curl (often needed for downloads)
    if ! command_exists curl; then
        print_warning "Curl not found. Some features may not work properly."
    fi
    
    print_status "Basic dependencies check completed"
}

# Main installation function
main() {
    print_status "Starting dotfiles installation..."
    
    # Get the directory where this script is located
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$DOTFILES_DIR"
    
    # Install dependencies
    install_dependencies
    
    # Run the Makefile dotfiles target
    print_status "Creating symbolic links for dotfiles..."
    make dotfiles
    
    # Install antidote
    install_antidote
    
    # Setup zsh
    setup_zsh
    
    # Final message
    print_status "Dotfiles installation completed!"
    echo
    print_status "Next steps:"
    echo "  1. Restart your terminal or run 'source ~/.zshrc'"
    echo "  2. The antidote plugin manager will automatically download plugins"
    echo "  3. Your shell environment should be fully configured"
    echo
    print_warning "Note: Some tools (mise, fzf, starship) may need to be installed separately:"
    echo "  - mise: https://mise.jdx.dev/"
    echo "  - fzf: https://github.com/junegunn/fzf"
    echo "  - starship: https://starship.rs/"
}

# Run main function
main "$@"