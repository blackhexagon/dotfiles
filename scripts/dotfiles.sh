#!/bin/bash

# Function to check and install a package if missing
install_if_missing() {
    if ! command -v "$1" &>/dev/null; then
        echo "$1 not found. Installing..."
        sudo apt update && sudo apt install -y "$2"
    else
        echo "$1 is already installed."
    fi
}

# Ensure Git is installed
install_if_missing git git

# Clone dotfiles repository
DOTFILES_DIR="$HOME/dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Cloning dotfiles repository..."
    git clone https://github.com/blackhexagon/dotfiles.git "$DOTFILES_DIR"
else
    echo "Dotfiles repository already exists."
fi

# Ensure Stow is installed
install_if_missing stow stow

# Stow the dotfiles
echo "Applying dotfiles with stow..."
cd "$DOTFILES_DIR" || exit
stow --target="$HOME" */

echo "Dotfiles setup completed!"

