#!/bin/bash

echo "Installing Kitty terminal on Ubuntu..."

# Check if kitty is already installed
if command -v kitty &>/dev/null; then
  echo "Kitty is already installed"
  kitty --version
else
  # Install kitty using curl
  echo "Downloading and installing Kitty..."
  curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

  # Create symlink for global access
  sudo ln -sf ~/.local/kitty.app/bin/kitty /usr/local/bin/
  sudo ln -sf ~/.local/kitty.app/bin/kitten /usr/local/bin/

  echo "Kitty installed successfully!"
fi

echo "Kitty installation complete!"

