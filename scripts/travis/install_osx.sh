#!/usr/bin/env bash

brew install nvm
source $(brew --prefix nvm)/nvm.sh
nvm install 0.10
nvm use 0.10
node --version
