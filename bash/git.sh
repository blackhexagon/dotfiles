aic() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git repository"
    return 1
  fi

  for tool in opencode jq fzf; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "$tool is required"
      return 1
    fi
  done

  git add . || return 1

  if git diff --cached --quiet; then
    echo "No staged changes"
    return 0
  fi

  local response final_json messages selection
  response=$(opencode run \
    "Review the staged git changes and suggest three concise commit messages. First inspect git status, git diff --staged, and git log --oneline -5. If needed, inspect key changed files for context. Prefer conventional commit format when it fits the repository history. Focus on why the change was made, not just what changed. Return only valid JSON with no markdown or commentary in this exact shape: {\"commitMessages\":[\"message one\",\"message two\",\"message three\"]}" \
    --model="openai/gpt-5.5-fast" \
    --agent="plan" \
    --format="json") || return 1

  final_json=$(printf "%s\n" "$response" | jq -rs -r 'map(select(.type == "text") | .part.text) | last // empty')

  if [ -z "$final_json" ]; then
    echo "Failed to find commit messages in opencode output"
    return 1
  fi

  messages=$(printf "%s\n" "$final_json" | jq -r '.commitMessages[]') || {
    echo "Failed to parse commit messages"
    return 1
  }

  if [ -z "$messages" ]; then
    echo "No commit messages returned"
    return 1
  fi

  selection=$(printf "%s\n" "$messages" | fzf --prompt="commit message> " --height=40% --reverse --no-multi)

  if [ -z "$selection" ]; then
    echo "No commit message selected"
    return 1
  fi

  git commit -m "$selection"
}

# Print the current branch name, or short SHA if detached (oh-my-zsh parity)
git_current_branch() {
  local ref
  ref=$(git symbolic-ref --quiet HEAD 2>/dev/null)
  local ret=$?
  if [ $ret -ne 0 ]; then
    [ $ret -eq 128 ] && return  # not a git repo
    ref=$(git rev-parse --short HEAD 2>/dev/null) || return
  fi
  echo "${ref#refs/heads/}"
}

# Print the main branch name (oh-my-zsh parity)
git_main_branch() {
  command git rev-parse --git-dir &>/dev/null || return
  local ref
  for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}; do
    if command git show-ref -q --verify "$ref"; then
      echo "${ref##*/}"
      return 0
    fi
  done
  echo master
  return 1
}

# Print the develop branch name (oh-my-zsh parity)
git_develop_branch() {
  command git rev-parse --git-dir &>/dev/null || return
  local branch
  for branch in dev devel develop development; do
    if command git show-ref -q --verify "refs/heads/$branch"; then
      echo "$branch"
      return 0
    fi
  done
  echo develop
  return 1
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
