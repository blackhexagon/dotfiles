aic() {
  git add .
  aicommits -g 3
}

# Navigate to project root
r() {
  cd "$(git rev-parse --show-toplevel 2>/dev/null)"
}

# Create a git worktree and open it in tmux
gwt() {
  emulate -L zsh
  setopt local_options no_aliases

  if [ -z "$1" ]; then
    echo "Usage: gwt <title>"
    return 1
  fi

  if [ ! -d "$PWD" ]; then
    echo "Current directory does not exist; please cd to a valid location"
    return 1
  fi

  if ! /usr/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository"
    return 1
  fi

  local root project title slug dest branch
  root=$(/usr/bin/git rev-parse --show-toplevel)
  project=$(basename "$root")
  title="$*"
  slug=$(printf "%s" "$title" | tr ' ' '-')
  dest="$root/../${project}-${slug}"
  branch="$slug"

  if [ -e "$dest" ]; then
    echo "Destination already exists: $dest"
    return 1
  fi

  if /usr/bin/git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "Branch already exists: $branch"
    return 1
  fi

  if /usr/bin/git worktree list --porcelain | /usr/bin/grep -q "^worktree $dest$"; then
    echo "Worktree already registered: $dest"
    return 1
  fi

  if ! /usr/bin/git worktree add -b "$branch" "$dest" >/dev/null; then
    echo "Failed to create worktree"
    return 1
  fi

  # Symlink common ignored files/directories from original worktree
  local symlink_items=("node_modules" ".env" "vendor")
  for item in "${symlink_items[@]}"; do
    if [ -e "$root/$item" ] && [ ! -e "$dest/$item" ]; then
      ln -s "$root/$item" "$dest/$item"
      echo "Symlinked $item"
    fi
  done

  echo "Created worktree at $dest on branch $branch"

  if [ -n "$TMUX" ]; then
    tmux new-window -c "$dest" -n "$slug"
  else
    cd "$dest"
  fi
}

# Merge a worktree branch into base and clean up
gwtm() {
  emulate -L zsh
  setopt local_options no_aliases

  if [ ! -x /usr/bin/fzf ]; then
    echo "fzf is required"
    return 1
  fi

  if [ ! -d "$PWD" ]; then
    echo "Current directory does not exist; please cd to a valid location"
    return 1
  fi

  if ! /usr/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository"
    return 1
  fi

  local root base
  root=$(/usr/bin/git rev-parse --show-toplevel)
  if /usr/bin/git show-ref --verify --quiet refs/heads/main; then
    base="main"
  elif /usr/bin/git show-ref --verify --quiet refs/heads/master; then
    base="master"
  else
    echo "No main/master branch found"
    return 1
  fi

  local choices selection branch path
  choices=$(/usr/bin/git worktree list --porcelain | /usr/bin/awk -v base="$base" '/^worktree /{w=$2} /^branch /{b=$2; sub("refs/heads/","",b); if (b != "" && b != base) printf "%s\t%s\n", b, w}')

  if [ -z "$choices" ]; then
    echo "No worktrees to merge"
    return 0
  fi

  selection=$(printf "%s\n" "$choices" | /usr/bin/fzf --prompt="worktree to merge> " --with-nth=1,2 --no-multi)
  if [ -z "$selection" ]; then
    echo "No selection"
    return 1
  fi

  branch=$(printf "%s" "$selection" | /usr/bin/awk -F '\t' '{print $1}')
  path=$(printf "%s" "$selection" | /usr/bin/awk -F '\t' '{print $2}')

  if [ -z "$branch" ] || [ -z "$path" ]; then
    echo "Invalid selection"
    return 1
  fi

  if [ -n "$(/usr/bin/git -C "$root" status --porcelain)" ]; then
    echo "Base worktree not clean: $root"
    return 1
  fi

  if [ -n "$(/usr/bin/git -C "$path" status --porcelain)" ]; then
    echo "Worktree not clean: $path"
    return 1
  fi

  # Rebase feature onto base to avoid merge commits
  if ! /usr/bin/git -C "$path" rebase "$base"; then
    echo "Rebase had conflicts; leaving worktree intact"
    return 1
  fi

  # Fast-forward base to the rebased branch
  if ! /usr/bin/git -C "$root" checkout "$base" >/dev/null; then
    echo "Failed to checkout $base"
    return 1
  fi

  if ! /usr/bin/git -C "$root" merge --ff-only "$branch"; then
    echo "Fast-forward failed; leaving worktree intact"
    return 1
  fi

  if /usr/bin/git worktree remove "$path" && /usr/bin/git branch -d "$branch"; then
    echo "Rebased $branch onto $base, fast-forwarded $base, and cleaned up worktree $path"
  else
    echo "Merge succeeded but cleanup failed; please check manually"
    return 1
  fi
}
