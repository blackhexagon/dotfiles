#!/bin/bash

set -e

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
CUSTOM_LAYOUT="$DOTFILES_DIR/keyboard/layout"
LAYOUT_NAME="u2b22"
TARGET_SYMBOLS="/usr/share/X11/xkb/symbols/$LAYOUT_NAME"
EVDEV_XML="/usr/share/X11/xkb/rules/evdev.xml"

# Check if custom layout file exists
if [[ ! -f "$CUSTOM_LAYOUT" ]]; then
    echo "Error: Custom layout file not found at $CUSTOM_LAYOUT"
    exit 1
fi

# Quatro/Wayland also searches user-local XKB symbols; no root is needed.
if [[ "${1:-}" == "--user" ]]; then
    TARGET_SYMBOLS="$HOME/.config/xkb/symbols/$LAYOUT_NAME"
    mkdir -p "$(dirname "$TARGET_SYMBOLS")"
    ln -sfn "$CUSTOM_LAYOUT" "$TARGET_SYMBOLS"
    echo "Symlinked $TARGET_SYMBOLS -> $CUSTOM_LAYOUT"
    exit 0
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root (e.g., sudo $0), or use --user on Wayland"
    exit 1
fi

# Symlink custom layout into the XKB symbols directory.
# The dotfile is the source of truth; editing it (no sudo needed) and
# reloading Hyprland is enough to apply changes.
echo "Installing custom keyboard layout..."
ln -sfn "$CUSTOM_LAYOUT" "$TARGET_SYMBOLS"
echo "  Symlinked $TARGET_SYMBOLS -> $CUSTOM_LAYOUT"

# Check if layout already exists in evdev.xml
if grep -q "<name>$LAYOUT_NAME</name>" "$EVDEV_XML"; then
    echo "  Layout entry already exists in evdev.xml"
else
    echo "  Adding layout entry to evdev.xml..."
    # Insert the layout entry before the closing </layoutList> tag
    sed -i "/<\/layoutList>/i\\
    <layout>\\
      <configItem>\\
        <name>$LAYOUT_NAME</name>\\
        <shortDescription>u2b22</shortDescription>\\
        <description>Czech (u2b22)</description>\\
        <languageList>\\
          <iso639Id>ces</iso639Id>\\
        </languageList>\\
      </configItem>\\
    </layout>" "$EVDEV_XML"
    echo "  Layout entry added to evdev.xml"
fi

echo ""
echo "Installation complete!"
echo ""
echo "To activate the layout on Quatro, add to ~/.config/hypr/input.lua:"
echo "  hl.config({ input = { kb_layout = \"$LAYOUT_NAME\" } })"
echo ""
echo "Then reload with:"
echo "  hyprctl reload"
echo ""
echo "Done."
