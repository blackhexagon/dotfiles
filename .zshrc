# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="$PATH:/usr/bin:/usr/local/go/bin:/snap/bin:/home/u2b22/.local/bin:$HOME/bin"
export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"
export FZF_DEFAULT_OPTS=" \
--color=bg+:#ccd0da,bg:#eff1f5,spinner:#dc8a78,hl:#d20f39 \
--color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#dc8a78 \
--color=marker:#7287fd,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39 \
--color=border:#ccd0da,label:#4c4f69"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Uncomment one of the following lines to change the auto-update behavior
zstyle ':omz:update' mode auto      # update automatically without asking

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 7

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

plugins=(
  git
  gh
  nvm
  npm
  git-open
  web-search
  fzf
  docker-compose
  zsh-autosuggestions
  zsh-syntax-highlighting
  tmux
  ubuntu
  gcloud
  you-should-use
)

# Load secret environment variables
if [ -f ~/.env ]; then
    source ~/.env
fi

# create .zcompdump files in cache file, not in home
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
alias vi="nvim ."
alias zshconf="$EDITOR ~/.zshrc"
alias lzd='lazydocker'
alias ll='eza --long --header --git --icons --all --group-directories-first --time-style=relative'
alias tree='eza --header --git --icons --long --header --tree --level 2 -a --group-directories-first'
alias treegnore='eza --header --git --icons --long --header --tree --level 2 -a --group-directories-first -I=.git --git-ignore'
alias gdd="~/scripts/goodday.sh"
alias scripts="cat package.json | jq --color-output '.scripts'"

# Bat
alias cat='bat'
export BAT_THEME="Catppuccin Latte"
export MANPAGER="sh -c 'awk '\''{ gsub(/\x1B\[[0-9;]*m/, \"\", \$0); gsub(/.\x08/, \"\", \$0); print }'\'' | bat -p -lman'"

# Load custom functions
if [ -f ~/dotfiles/.zsh_functions ]; then
  source ~/dotfiles/.zsh_functions
fi

# enable zoxide
eval "$(zoxide init zsh)"

# source /usr/share/nvm/init-nvm.sh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
