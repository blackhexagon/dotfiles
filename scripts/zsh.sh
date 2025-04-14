#!/bin/bash

# Update package lists
sudo apt update

# Install Zsh
sudo apt install -y zsh

# Verify installation
if ! command -v zsh &> /dev/null
then
    echo "Zsh installation failed. Exiting."
    exit 1
fi

echo "Zsh installed successfully."

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Set Zsh as the default shell
chsh -s $(which zsh)

echo "Installation complete. Restart your terminal or log out and back in for changes to take effect."
