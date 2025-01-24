# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="$PATH:/home/matous/.config/composer/vendor/bin"
# For AI chat without quotes
setopt NO_NOMATCH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export EDITOR="phpstorm"
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

# Theme
ZSH_THEME="agnoster"

# Uncomment one of the following lines to change the auto-update behavior
zstyle ':omz:update' mode auto      # update automatically without asking

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 7

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

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
git-open
web-search
fzf
docker-compose
zsh-autosuggestions
zsh-syntax-highlighting
)

# Load secret environment variables
if [ -f ~/.env ]; then
    source ~/.env
fi

# create .zcompdump files in cache file, not in home
export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST

source $ZSH/oh-my-zsh.sh

#unalias
unalias chatgpt


# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

alias zshconf="micro ~/.zshrc"
alias ohmyzsh="micro ~/.oh-my-zsh"
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
alias update='bash ~/scripts/update.sh'
alias lzd='lazydocker'
alias ll='eza --long --header --git --icons --all --group-directories-first --time-style=relative'
alias tree='eza --header --git --icons --long --header --tree --level 2 -a --group-directories-first'
alias treegnore='eza --header --git --icons --long --header --tree --level 2 -a --group-directories-first -I=.git --git-ignore'
alias o='phpstorm $(rg --files | fzf) && clear'
alias storm='phpstorm $1'
alias gdd="sh ~/scripts/goodday.sh"
alias ccsv="xclip -o > ~/anki/clipboard.csv"
alias scripts="cat package.json | jq --color-output '.scripts'"

flac2mp3() {
	find . -type f -name "*.flac" -exec sh -c 'ffmpeg -i "$0" -b:a 320k -map_metadata 0 -id3v2_version 3 "${0%.flac}.mp3" && rm "$0"' {} \;
}

ogg2mp3() {
	find . -type f -name "*.ogg" -exec sh -c 'ffmpeg -i "$0" -b:a 320k -map_metadata 0 -id3v2_version 3 "${0%.ogg}.mp3" && rm "$0"' {} \;
}

aic() {
  git add .
  aicommits -g 3
}

ai() {
  dt=$(date +"%y-%m-%d_%H:%M:%S")
  input="$*"
  trim=${input:0:40}
  file="$HOME/chatgpt/${dt}_${trim}.md"
  chatgpt -k $OPENAI_API_KEY -m gpt-4o -c $input | tee $file
  clear
  echo -e "> ${input}\n\n$(< ${file})" > $file
  glow $file
}

aihist() {                                            
  local file                                                              
  file=$(ls -t $HOME/chatgpt/* | fzf) && glow "$file"
}

ggl() {
  googler "$*"
}

fif() {
  if [ ! "$#" -gt 0 ]; then echo "Need a string to search for!"; return 1; fi
  rg --files-with-matches --no-messages "$1" | fzf --preview "highlight -O ansi -l {} 2> /dev/null | rg --colors 'match:bg:yellow' --ignore-case --pretty --context 10 '$1' || rg --ignore-case --pretty --context 10 '$1' {}" | xargs phpstorm
}

# Navigating to project root
r () {
    cd "$(git rev-parse --show-toplevel 2>/dev/null)"
}

editor() {                                                     
    nohup phpstorm "$@" &>/dev/null &                              
}  

# Remove username & machine from the prompt
prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    #prompt_segment black default "%(!.%{%F{yellow}%}.)$USER"
  fi
}

killport() {                                                                                             
  # Prompt the user for the port number                                                                           
  read -p "Enter the port number you want to kill: " port                                                         
                                                                                                                  
  # Find the process ID (PID) using `ss` and `awk`                                                                
  pid=$(sudo ss -ltnp | grep ":$port" | awk '{for(i=1;i<=NF;i++) if($i ~ "pid=") print substr($i,5)}')            
                                                                                                                  
  # Check if we got a PID                                                                                         
  if [ ! -z "$pid" ]; then                                                                                        
    echo "Killing process with PID $pid on port $port"                                                            
                                                                                                                  
    # Attempt to kill the process gently with SIGTERM                                                             
    sudo kill $pid                                                                                                
                                                                                                                  
    # If the process does not terminate after some time, force it to close                                        
    if kill -0 $pid 2>/dev/null; then                                                                             
      echo "Process did not terminate, forcing it to stop..."                                                     
      sudo kill -9 $pid                                                                                           
    fi                                                                                                            
                                                                                                                  
    echo "Process killed."                                                                                        
  else                                                                                                            
    echo "No process found running on port $port."                                                                
  fi                                                                                                              
}          

# enable zoxide
eval "$(zoxide init zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
