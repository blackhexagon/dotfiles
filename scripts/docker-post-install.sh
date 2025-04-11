#!/bin/sh

sudo groupadd docker
sudo usermod -aG docker $USER
newgrp dockernewgrp docker

# run on start
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
