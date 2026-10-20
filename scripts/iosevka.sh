#!/bin/bash

# Installs IosevkaTerm Nerd Font (used by foot).

set -e

FONT_FAMILY="IosevkaTerm Nerd Font"

if fc-list | grep -Fqi "$FONT_FAMILY"; then
    echo "$FONT_FAMILY is already installed."
    exit 0
fi

if command -v omarchy &>/dev/null; then
    omarchy pkg add ttf-iosevkaterm-nerd
else
    FONT_DIR="$HOME/.local/share/fonts/IosevkaTerm"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/IosevkaTerm.zip"
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    echo "Downloading $FONT_FAMILY..."
    wget -q --show-progress -O "$TMP_DIR/IosevkaTerm.zip" "$FONT_URL"

    mkdir -p "$FONT_DIR"
    unzip -o "$TMP_DIR/IosevkaTerm.zip" -d "$FONT_DIR"

    echo "Updating font cache..."
    fc-cache -f
fi

echo "Installation complete! $FONT_FAMILY is now available."
