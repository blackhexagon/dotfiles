# Pick the default audio output sink interactively with fzf.
# Node IDs are dynamic (they change on device reconnect), so they are
# resolved fresh on each call. The currently active sink is marked with a dot.
audio-out() {
  for tool in wpctl fzf; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "$tool is required"
      return 1
    fi
  done

  local selection id name
  selection=$(wpctl status | awk '
    /Sinks:/   { insink = 1; next }
    /Sources:/ { insink = 0 }
    insink && match($0, /[0-9]+\./) {
      marker = (index($0, "*") ? "●" : " ")
      # Strip tree glyphs, leading "*", and surrounding whitespace.
      sub(/^[^0-9*]*\*?[[:space:]]*/, "")
      printf "%s %s\n", marker, $0
    }' | fzf --prompt="default sink> " --height=40% --reverse --no-multi)

  [ -z "$selection" ] && return 0 # cancelled

  id=$(printf '%s' "$selection" | grep -oE '[0-9]+' | head -n1)
  name=$(printf '%s' "$selection" | sed -E 's/^[^0-9]*[0-9]+\.[[:space:]]*//; s/[[:space:]]*\[vol:.*$//')

  if [ -z "$id" ]; then
    echo "Could not parse sink id from: $selection"
    return 1
  fi

  wpctl set-default "$id" && echo "Default sink -> $name (node $id)"
}
