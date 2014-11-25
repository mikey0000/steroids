#!/usr/bin/env bash

cd "$(dirname "$0")"

UNAME=$(uname)

if [ "$UNAME" = "Darwin" ]; then
  echo "running install_osx.sh"
  ./install_osx.sh
elif [ "$UNAME" = "Linux" ]; then
  echo "running install_linux.sh"
  ./install_linux.sh
else
  echo "Unknown uname: $UNAME"
fi
