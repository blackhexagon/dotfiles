# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

source ~/completion-for-pnpm.bash

if [ -f ~/.env ]; then
  source ~/.env
fi

if [ -f ~/dotfiles/.zsh_functions ]; then
  source ~/dotfiles/.zsh_functions
fi

export PATH="$HOME/.config/composer/vendor/bin:$PATH"
. "$HOME/.local/share/../bin/env"

alias vi="nvim ."
alias ll='eza --long --header --git --icons --all --group-directories-first --time-style=relative'
alias cat='bat -pp'
alias scripts="cat package.json | jq --color-output '.scripts'"
alias laptop-off='hyprctl keyword monitor eDP-1,disable,auto,auto'
alias laptop-on='hyprctl keyword monitor eDP-1,preferred,auto,auto'

# opencode
export PATH=/home/u2b22/.opencode/bin:$PATH
