#!/bin/sh

# Install ascii image converter
echo 'deb [trusted=yes] https://apt.fury.io/ascii-image-converter/ /' | sudo tee /etc/apt/sources.list.d/ascii-image-converter.list
sudo apt update
sudo apt install -y ascii-image-converter
# instgall nvim with snap to use the latest version
sudo snap install nvim --classic
