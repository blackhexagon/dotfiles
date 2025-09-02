#!/bin/sh
sudo apt install bat
mkdir -p "$(batcat --config-dir)/themes"
wget -P "$(batcat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Latte.tmTheme
batcat cache --build
