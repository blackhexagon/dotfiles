#!/bin/sh

# Detect OS and install tmux with appropriate package manager
if [ -f /etc/arch-release ]; then
    sudo pacman -S --noconfirm tmux cmake
elif [ -f /etc/debian_version ]; then
    sudo apt install -y tmux cmake
else
    echo "Unsupported OS"
    exit 1
fi
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
~/.tmux/plugins/tpm/bin/install_plugins

# Build tmux-mem-cpu-load plugin
cd ~/.tmux/plugins/tmux-mem-cpu-load
cmake .
make
sudo make install
