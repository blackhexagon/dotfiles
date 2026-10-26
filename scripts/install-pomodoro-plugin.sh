#!/bin/bash
# Install the u2b22.pomodoro Omarchy plugin from this repo.
#
# Omarchy refuses symlinks inside a plugin folder, so the plugin is copied, not
# stowed. The repo copy is the source of truth; re-run this after editing it.
# The widget is added next to the clock in both the live and the repo
# shell.json; nothing else in either bar is changed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ID="u2b22.pomodoro"
SOURCE="$DOTFILES_DIR/omarchy/plugins/$PLUGIN_ID"
DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
CONFIG_DIR="$HOME/.config/omarchy/u2b22-pomodoro"
SHELL_CONFIGS=("$HOME/.config/omarchy/shell.json" "$DOTFILES_DIR/.config/omarchy/shell.json")

if [[ ! -f "$SOURCE/manifest.json" ]]; then
    echo "Error: plugin source not found at $SOURCE"
    exit 1
fi

for tool in jq omarchy-plugin-validate; do
    if ! command -v "$tool" &>/dev/null; then
        echo "Error: $tool is required"
        exit 1
    fi
done

omarchy-plugin-validate "$SOURCE"

echo "Copying $PLUGIN_ID to $DEST..."
mkdir -p "$(dirname "$DEST")"
rm -rf "${DEST:?}"
cp -r "$SOURCE" "$DEST"
find "$DEST" -name __pycache__ -prune -exec rm -rf {} +

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# Insert the widget right after omarchy.clock in the center section, unless it
# is already somewhere in the bar.
add_widget() {
    local file target tmp
    file="$1"
    if [[ ! -f "$file" ]]; then
        echo "  Skipping missing $file"
        return
    fi
    target="$(readlink -f "$file")"
    if jq -e --arg id "$PLUGIN_ID" \
        '[.bar.layout[]?[]? | select(.id == $id)] | length > 0' "$target" >/dev/null; then
        echo "  $file already has $PLUGIN_ID"
        return
    fi
    tmp="$(mktemp "$(dirname "$target")/.shell.json.XXXXXX")"
    jq --arg id "$PLUGIN_ID" '
        .bar.layout.center = (
            (.bar.layout.center // []) as $center
            | ($center | map(.id) | index("omarchy.clock")) as $clock
            | if $clock == null then [{id: $id, calendar: "Work"}] + $center
              else $center[:$clock + 1] + [{id: $id, calendar: "Work"}] + $center[$clock + 1:]
              end)' "$target" >"$tmp"
    chmod --reference="$target" "$tmp"
    mv "$tmp" "$target"
    echo "  Added $PLUGIN_ID to $file"
}

echo "Enabling the bar widget..."
for config in "${SHELL_CONFIGS[@]}"; do
    add_widget "$config"
done

if command -v omarchy-shell &>/dev/null; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi

echo "Installed $PLUGIN_ID."
echo "If the widget shows a warning, click it and choose Connect Google."
