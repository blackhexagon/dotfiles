#!/bin/sh

npm install -g aicommits

# Prompt for Bitwarden login
echo "Logging in to Bitwarden..."
bw login --check &> /dev/null
if [ $? -ne 0 ]; then
    bw login
fi

BW_SESSION=$(bw unlock --raw)
export BW_SESSION

# Get the note from Bitwarden
TOKEN=$(bw get notes "openai aicommits key" --session "$BW_SESSION")
if [ $? -ne 0 ]; then
  echo "❌ Failed to get the openai key from Bitwarden."
  exit 1
fi

# Set the token in aicommits
aicommits config set OPENAI_KEY="$TOKEN"
