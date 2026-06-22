#!/usr/bin/env bash
set -euo pipefail

FOLDER_ID="e498fd3f-1cd2-43f5-bfe3-b47100bf6e5c"
SSH_DIR="$HOME/.ssh"
KEYS_DIR="$SSH_DIR/keys"

# Verify required tools are present (do NOT install them).
# Works across distros (Debian, Arch, etc.) since nothing is installed here.
for cmd in bw jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

# Log in to Bitwarden if not already authenticated.
if ! bw login --check >/dev/null 2>&1; then
  bw login
fi

# Sync and unlock the vault.
bw sync
BW_SESSION="$(bw unlock --raw)"
export BW_SESSION

# Prepare the keys directory with correct permissions.
mkdir -p "$KEYS_DIR"
chmod 700 "$SSH_DIR"
chmod 700 "$KEYS_DIR"

# Fetch items from the target folder and write each SSH key.
bw list items --folderid "$FOLDER_ID" --session "$BW_SESSION" |
  jq -c '.[] | select(.sshKey != null)' |
  while read -r item; do
    name="$(printf '%s' "$item" | jq -r '.name')"
    private_key="$(printf '%s' "$item" | jq -r '.sshKey.privateKey // empty')"
    public_key="$(printf '%s' "$item" | jq -r '.sshKey.publicKey // empty')"

    if [ -n "$private_key" ]; then
      dest="$KEYS_DIR/$name"
      printf '%s\n' "$private_key" >"$dest"
      chmod 600 "$dest"
      echo "Saved private key: $dest"
    fi

    if [ -n "$public_key" ]; then
      pub_dest="$KEYS_DIR/$name.pub"
      printf '%s\n' "$public_key" >"$pub_dest"
      chmod 644 "$pub_dest"
      echo "Saved public key: $pub_dest"
    fi
  done

# Log out of Bitwarden.
bw logout

echo "SSH key setup complete!"
