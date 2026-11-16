# clip [name] – save clipboard content into the current directory
#   image          → clip-<timestamp>.<ext> (or <name>)
#   copied files   → copied into cwd
#   text           → clip-<timestamp>.txt (or <name>)
clip() {
  local types mime ext name uri path
  types=$(wl-paste --list-types 2>/dev/null) || {
    echo "clip: clipboard is empty" >&2
    return 1
  }

  if mime=$(grep -m1 '^image/' <<<"$types"); then
    ext=${mime#image/}
    ext=${ext%%;*}
    [[ $ext == jpeg ]] && ext=jpg
    [[ $ext == svg+xml ]] && ext=svg
    name=${1:-clip-$(date +%Y%m%d-%H%M%S).$ext}
    wl-paste --type "$mime" >"$name" || return 1
  elif grep -qx 'text/uri-list' <<<"$types"; then
    while IFS= read -r uri; do
      uri=${uri%$'\r'}
      [[ $uri == file://* ]] || continue
      path=${uri#file://}
      path=$(printf '%b' "${path//%/\\x}")
      cp -iv -- "$path" .
    done < <(wl-paste --type text/uri-list)
    return
  else
    name=${1:-clip-$(date +%Y%m%d-%H%M%S).txt}
    wl-paste --no-newline >"$name" || return 1
  fi

  echo "→ $name"
}
