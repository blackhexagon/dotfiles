#!/bin/bash

curl -Lo phpactor.phar https://github.com/phpactor/phpactor/releases/latest/download/phpactor.phar
chmod a+x phpactor.phar
sudo mv phpactor.phar /usr/local/bin
phpactor status
