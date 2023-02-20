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

    apt-get install -y python3-pip upgrade

    # apt-get install -y software-properties-common
    # add-apt-repository ppa:deadsnakes/ppa
    # apt-cache policy python3.9
    # apt-get update
    # apt-get install -y python3.9 python3.9-distutils
    # curl https://bootstrap.pypa.io/pip/get-pip.py -o get-pip.py
    # python3.9 get-pip.py

    if [ "$DEBUG" == "true" ]; then
      echo "Python: $(python3 --version)"
      echo "Pip: $(python3 -m pip --version)"
    fi

    echo "Installing additional tools & libraries..."
    apt-get install -y gcc make zlib1g-dev libc-dev libffi-dev g++ libxml2 libxml2-dev libxslt-dev libcurl4-openssl-dev libssl-dev libgnutls28-dev

    # Workaround for python bug:  AttributeError: module 'collections' has no attribute 'Callable'
    pip3 uninstall -y pyreadline
    pip3 install pyreadline3
    pip3 uninstall -y nose
    pip3 install nose-py3
else
    echo "Python version not supported ..."
  	exit 99
fi
