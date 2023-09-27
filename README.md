#### Set up SSH
```
mkdir .ssh
touch .ssh/id_rsa
touch .ssh/id_rsa.pub
sudo chown 600 .ssh/id_rsa
sudo chown 600 .ssh/id_rsa.pub
```
Populate with content from password manager

#### Install [Oh My ZSH](https://ohmyz.sh/)

```
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```


#### Make zsh default if you haven't already:
```
chsh -s $(which zsh)
```

#### Sync dotfiles

Make sure that your source repository ignores the folder where you'll clone it, so that you don't create weird recursion problems:
```
echo ".cfg" >> .gitignore
```

Clone the repo
```
git clone --bare git@github.com:blackhexagon/dotfiles.git $HOME/.cfg
```

Define the alias in the current shell scope:
```
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
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
