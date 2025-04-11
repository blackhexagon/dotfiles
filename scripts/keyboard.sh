#!/bin/bash

# Define paths
USER_HOME=$(eval echo ~${SUDO_USER})
CUSTOM_LAYOUT="$USER_HOME/keyboard/layout"
TARGET_LAYOUT="/usr/share/X11/xkb/symbols/cz"
# Check if running as root
# if [[ $EUID -ne 0 ]]; then
#   echo "Please run this script as root (e.g., sudo ./script.sh)"
#   exit 1
# fi

# Append custom layout
echo "Appending custom layout..."
cat "$CUSTOM_LAYOUT" >>"$TARGET_LAYOUT"

sudo nano /usr/share/X11/xkb/rules/evdev.xml
# <variant>
#   <configItem>
#     <name>u2b22</name>
#     <description>Czech (u2b22)</description>
#   </configItem>
# </variant>

gsettings set org.gnome.desktop.input-sources xkb-options "['lv3:ralt_switch']"

echo 'Updating /etc/default/keyboard...'

sudo bash -c 'cat > /etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="cz"
XKBVARIANT="u2b22"
XKBOPTIONS="lv3:ralt_switch"
EOF'

sudo dpkg-reconfigure keyboard-configuration

echo "Done."
