#!/bin/sh

curl -fsSL https://ddev.com/install.sh | bash

# enable ports
sudo setcap cap_net_bind_service=ep /usr/bin/rootlesskit
systemctl --user restart docker
