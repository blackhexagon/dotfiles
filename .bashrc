# If not running interactively, don't do anything (leave this at the top of this file)
# [[ $- == *i* ]] && source -- /usr/share/blesh/ble.sh --attach=none
[[ $- == *i* ]] && source /usr/share/blesh/ble.sh --noattach

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$HOME/.local/share/omarchy/default/bash/rc"

source "$HOME/completion-for-pnpm.bash"
source "$HOME/.env"
source "$HOME/bash/git.sh"
source "$HOME/bash/tmux.sh"
source "$HOME/bash/pwd.sh"

export PATH="$HOME/.opencode/bin:$HOME/.config/composer/vendor/bin:$HOME/.local/share/../bin/env:$PATH"
export EDITOR="nvim"

alias vi="nvim ."
alias ll='eza --long --header --git --icons --all --group-directories-first --time-style=relative'
alias cat='bat -pp'
alias scripts="cat package.json | jq --color-output '.scripts'"
alias laptop-off='hyprctl keyword monitor eDP-1,disable,auto,auto'
alias laptop-on='hyprctl keyword monitor eDP-1,preferred,auto,auto'
alias grhh='git reset --hard'
alias gsb='git status --short --branch'
alias gcan!='git commit --verbose --all --no-edit --amend'
alias glog='git log --oneline --decorate --graph'
alias ggpull='git pull origin "$(git_current_branch)"'
alias ggpush='git push origin "$(git_current_branch)"'
alias gcm='git checkout "$(git_main_branch)"'
alias gcd='git checkout "$(git_develop_branch)"'

killport() {
  # Get port from argument or prompt
  local port=$1
  if [ -z $port ]; then
    read -p Enter the port number you want to kill: port
  fi

  # Use fuser to kill all processes on the port
  if sudo fuser -k $port/tcp 2>/dev/null; then
    sleep 1
    if sudo fuser $port/tcp 2>/dev/null | grep -q .; then
      echo Process did not terminate, forcing it to stop...
      sudo fuser -k -9 $port/tcp 2>/dev/null
    fi
    echo Process killed.
  else
    echo No process found running on port $port.
  fi
}

fif() {
  if [ ! "$#" -gt 0 ]; then
    echo "Need a string to search for!"
    return 1
  fi
  rg --files-with-matches --no-messages "$1" | fzf --preview 'bat -pp --color=always {}' --preview-window '~3' | xargs $EDITOR
}

[[ ! ${BLE_VERSION-} ]] || ble-attach
