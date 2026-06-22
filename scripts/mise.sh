#!/bin/sh

sudo apt install -y extrepo
sudo extrepo enable mise
sudo apt update
sudo apt install -y mise
