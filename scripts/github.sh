#!/bin/sh

sudo apt install gh
gh auth login
gh config set git_protocol ssh
mkdir $HOME/projects
