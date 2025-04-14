#!/bin/bash

# Define variables
FONT_DIR="$HOME/.local/share/fonts"
FONT_NAME="JetBrainsMono"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT_NAME}.zip"
TMP_DIR="/tmp/${FONT_NAME}-nerdfont"

# Create a temporary directory
mkdir -p "$TMP_DIR"

# Download the font
echo "Downloading JetBrains Mono Nerd Font..."
wget -q --show-progress -O "$TMP_DIR/${FONT_NAME}.zip" "$FONT_URL"

# Create font directory if it doesn't exist
mkdir -p "$FONT_DIR"

# Unzip the font to the font directory
echo "Extracting font..."
unzip -o "$TMP_DIR/${FONT_NAME}.zip" -d "$FONT_DIR"

# Refresh font cache
echo "Updating font cache..."
fc-cache -fv

# Clean up
rm -rf "$TMP_DIR"

echo "Installation complete! JetBrains Mono Nerd Font is now available."
