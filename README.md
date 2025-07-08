## Set up SSH

```
mkdir .ssh
touch .ssh/id_rsa
touch .ssh/id_rsa.pub
sudo chown 600 .ssh/id_rsa
sudo chown 600 .ssh/id_rsa.pub
```

Populate with content from password manager

## Tools

## Install Oh My ZSH

```
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

#### Make zsh default if you haven't already

```
chsh -s $(which zsh)
```

#### Instal ZSH plugins

##### [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)

```
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

##### [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions/tree/master)

```
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

##### [git-open](https://github.com/paulirish/git-open)

```
git clone https://github.com/paulirish/git-open.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/git-open
```

## Sync dotfiles

Make sure that your source repository ignores the folder where you'll clone it, so that you don't create weird recursion problems:

```
echo ".cfg" >> .gitignore
```

Clone the repo

```
git clone --bare git@github.com:blackhexagon/dotfiles.git $HOME/.cfg
```

Restart the shell

```
source .zshrc
```

We set a flag - local to the repository - to hide files we are not explicitly tracking yet. This is so that when you type config status and other commands later, files you are not interested in tracking will not show up as untracked.

```
config config --local status.showUntrackedFiles no
```

Checkout the actual content from the bare repository to your $HOME

```
config checkout
```

Remove the conflicting files
