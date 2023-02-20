#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Initialize Dependencies '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_LANGUAGE_VERSION=$1

if [ "$DEBUG" == "true" ]; then
    echo "DEBUG - Script input variables..."
    echo "BUILD_LANGUAGE_VERSION=$BUILD_LANGUAGE_VERSION"
fi

if [ "$BUILD_LANGUAGE_VERSION" == "2" ]; then
    echo "Python 2 no longer supported ..."
    exit 89
elif [ "$BUILD_LANGUAGE_VERSION" == "3" ]; then
    echo "Installing Python 3 ..."

    apt-get --purge -y autoremove python3-pip
    apt-get install -y python3-pip
    apt-get install -y python3-distutils

    curl https://bootstrap.pypa.io/pip/get-pip.py -o get-pip.py
    python3 get-pip.py

    if [ "$DEBUG" == "true" ]; then
      echo "Python: $(python3 --version)"
      echo "Pip: $(python3 -m pip --version)"
    fi

    echo "Installing additional tools & libraries..."
    apt-get install -y gcc make zlib1g-dev libc-dev libffi-dev g++ libxml2 libxml2-dev libxslt-dev libcurl4-openssl-dev libssl-dev libgnutls28-dev

    # Workaround for python bug:  AttributeError: module 'collections' has no attribute 'Callable'
    python3 -m pip uninstall -y pyreadline
    python3 -m pip install pyreadline3
    python3 -m pip uninstall -y nose
    python3 -m pip install -U nose-py3 --no-binary :all:
else
    echo "Python version not supported ..."
  	exit 99
fi
