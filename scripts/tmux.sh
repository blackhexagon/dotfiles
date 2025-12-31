#!/bin/sh

# Detect OS and install tmux with appropriate package manager
if [ -f /etc/arch-release ]; then
    sudo pacman -S --noconfirm tmux
elif [ -f /etc/debian_version ]; then
    sudo apt install -y tmux
else
    echo "Unsupported OS"
    exit 1
fi
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
tmux source ~/.tmux.conf
