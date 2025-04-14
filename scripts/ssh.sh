#!/bin/bash

# Install Bitwarden CLI
if ! command -v bw &> /dev/null
then
    echo "Installing Bitwarden CLI..."
    sudo snap install bw
fi

# Prompt for Bitwarden login
echo "Logging in to Bitwarden..."
bw login --check &> /dev/null
if [ $? -ne 0 ]; then
    bw login
fi

# sync
bw sync

# Unlock the vault
BW_SESSION=$(bw unlock --raw)
export BW_SESSION

# Retrieve SSH keys from Bitwarden
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
KEY_PATH="$SSH_DIR/id_rsa"

if [ -f "$KEY_PATH" ]; then
    echo "SSH key already exists in .ssh folder. Skipping retrieval."
else
    echo "Retrieving SSH private key from Bitwarden..."
    bw get notes ssh_private --session "$BW_SESSION" > "$KEY_PATH"
    chmod 600 "$KEY_PATH"
    echo "Private key copied to .ssh folder."
fi

if [ -f "$KEY_PATH.pub" ]; then
    echo "SSH public key already exists in .ssh folder. Skipping retrieval."
else
    echo "Retrieving SSH public key from Bitwarden..."
    bw get notes ssh_public --session "$BW_SESSION" > "$KEY_PATH.pub"
    chmod 644 "$KEY_PATH.pub"
    echo "Public key copied to .ssh folder."
fi

# Logout of Bitwarden
bw logout

echo "SSH key setup complete!"
