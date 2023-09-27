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

Checkout the actual content from the bare repository to your $HOME
```
config checkout
```
Remove the conflicting files
