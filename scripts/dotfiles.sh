#!/bin/bash

# Function to check and install a package if missing
install_if_missing() {
    if ! command -v "$1" &>/dev/null; then
        echo "$1 not found. Installing..."
        if command -v omarchy &>/dev/null; then
            omarchy pkg add "$2" || exit 1
        else
            sudo apt update && sudo apt install -y "$2" || exit 1
        fi
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
    git clone https://github.com/blackhexagon/dotfiles.git "$DOTFILES_DIR" || exit 1
else
    echo "Dotfiles repository already exists."
fi

# Ensure Stow is installed
install_if_missing stow stow

# The repository is a single Stow package, including its hidden dotfiles.
echo "Applying dotfiles with stow..."
stow --dir="$DOTFILES_DIR" --target="$HOME" --no-folding \
    --ignore='^(\.git|\.gitignore|README\.md|scripts|keyboard|skills\.sh|wallpaper\.jpg|\.env\.example)$' \
    "$@" . || exit 1

echo "Dotfiles setup completed!"

