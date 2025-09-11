# Dotfiles Setup

Automated setup for new computers with proper dependency management and error handling.

## Quick Start

### Automated Setup (Recommended)

```bash
# Clone the repository
git clone https://github.com/blackhexagon/dotfiles.git
cd dotfiles

# Run automated setup
./master-setup.sh
```

### Setup Options

```bash
# Interactive setup with prompts (default)
./master-setup.sh

# Fully automated (skip interactive scripts)
./master-setup.sh --unattended

# Preview what would be executed
./master-setup.sh --dry-run

# Resume after shell restart
./master-setup.sh --resume

# Install specific phase only
./master-setup.sh --phase dev-tools

# Reset and start fresh
./master-setup.sh --reset
```

## Setup Phases

The automated setup runs in these phases with proper dependency management:

### 1. Foundation
- **essential-installs.sh** - Base system packages
- **zsh.sh** - Zsh shell installation (requires terminal restart)

### 2. Shell Configuration  
- **zsh-plugins.sh** - Oh My Zsh plugins
- **font.sh** - JetBrains Mono Nerd Font

### 3. Development Tools
- **nvm.sh** - Node Version Manager
- **github.sh** - GitHub CLI (interactive)
- **neovim.sh** - Neovim editor
- **docker.sh** - Docker installation
- **docker-post-install.sh** - Docker post-setup

### 4. Configuration
- **tmux.sh** - Terminal multiplexer
- **dotfiles.sh** - Apply configurations with stow (interactive)

### 5. Customization
- **keyboard.sh** - Custom keyboard layout (interactive)

### 6. Optional Tools
- **bat.sh**, **gcloud.sh**, **phpactor.sh**, **ddev.sh**
- **aicommits.sh**, **style-gnome-terminal.sh**

## Features

- **Smart dependency management** - Scripts run in correct order
- **Shell restart handling** - Automatic resume after zsh installation
- **Error recovery** - Retry failed scripts, continue on non-critical failures
- **Interactive script management** - Skip or run scripts requiring user input
- **Idempotent execution** - Safe to re-run, skips completed scripts
- **Progress tracking** - Visual progress and detailed logging
- **Flexible execution** - Run all, specific phases, or individual scripts

## Manual Setup (Legacy)

If you prefer manual control, you can still run individual scripts:

### Set up SSH

```bash
mkdir .ssh
touch .ssh/id_rsa .ssh/id_rsa.pub
chmod 600 .ssh/id_rsa .ssh/id_rsa.pub
```

Populate with content from password manager.

### Individual Scripts

All scripts are located in the `scripts/` directory:

```bash
# Essential packages
./scripts/essential-installs.sh

# Zsh setup (requires restart)
./scripts/zsh.sh
# After restart:
./scripts/zsh-plugins.sh

# Development tools
./scripts/nvm.sh
./scripts/github.sh  # Interactive
./scripts/neovim.sh
./scripts/docker.sh
./scripts/docker-post-install.sh

# Configuration
./scripts/tmux.sh
./scripts/dotfiles.sh  # Interactive
```

## Troubleshooting

- **Setup logs**: Check `~/.dotfiles-setup.log` for detailed execution logs
- **Resume setup**: Use `./master-setup.sh --resume` after interruptions  
- **Reset state**: Use `./master-setup.sh --reset` to start fresh
- **Individual scripts**: Run specific scripts manually if needed

## Legacy Dotfiles Sync (Manual Method)

For manual dotfiles management using bare git repo:

```bash
# Create bare repo
git clone --bare git@github.com:blackhexagon/dotfiles.git $HOME/.cfg

# Set up config alias
echo "alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'" >> ~/.bashrc
source ~/.bashrc

# Hide untracked files
config config --local status.showUntrackedFiles no

# Checkout dotfiles
config checkout
```
