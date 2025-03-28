#!/bin/bash

# Update and display outdated pacman packages
echo "Checking for outdated pacman packages..."
sudo pacman -Sy
sudo pacman -Qu

# Update and display outdated snap packages
echo "Checking for outdated snap packages..."
sudo snap refresh --list

# Update and display outdated npm global packages
echo "Checking for outdated npm global packages..."
npm outdated -g --depth=0

# Prompt user to update packages
read -p "Do you want to update all packages? (y/n): " choice
if [ "$choice" == "y" ]; then
  # Update pacman packages
  echo "Updating pacman packages..."
  sudo pacman -Syu

  # Update snap packages
  echo "Updating snap packages..."
  sudo snap refresh

  # Update npm global packages
  echo "Updating npm global packages..."
  sudo npm update -g

  echo "All packages have been updated."
else
  echo "No packages were updated."
fi
