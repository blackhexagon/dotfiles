#!/usr/bin/env bash
# Install the Omarchy shell plugins used by these dotfiles.
# Bar placement and widget settings come from .config/omarchy/shell.json,
# so plugins are only added here, never enabled (that would rewrite shell.json).
# Already installed plugins are skipped; update them with: omarchy plugin update
set -euo pipefail

PLUGINS=(
  https://github.com/PixDevsApps/omarchy-hertz-radio.git
  https://github.com/aronnaxlin/omarchy-anki-status-plugin.git
  https://github.com/Expri-commits/omarchy-anki-theme
  https://github.com/meviusisback/omarchy-hw-monitor.git
  https://github.com/techywilbur/omarchy-pomodoro.git
)
# io.voxtype.settings ships with the voxtype package, not from git.

PLUGINS_DIR="$HOME/.config/omarchy/plugins"

normalize() {
  local url=${1%/}
  echo "${url%.git}"
}

installed_urls() {
  local dir
  for dir in "$PLUGINS_DIR"/*/; do
    [[ -d $dir/.git ]] || continue
    normalize "$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
  done
}

command -v omarchy >/dev/null || { echo "omarchy not found" >&2; exit 1; }

installed=$(installed_urls)
for url in "${PLUGINS[@]}"; do
  if grep -qxF "$(normalize "$url")" <<<"$installed"; then
    echo "Skipping $url (already installed)"
    continue
  fi
  omarchy plugin add "$url" --yes
done
