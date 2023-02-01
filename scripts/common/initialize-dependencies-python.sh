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
    echo "Uninstalling default Python version ..."
    apt-get remove -y –-auto-remove python3-pip
    echo "Installing Python 3.9 ..."
    apt-get install -y software-properties-common
    add-apt-repository ppa:deadsnakes/ppa
    apt-cache policy python3.9
    apt-get update
    apt-get install -y python3.9 python3.9-distutils

    ls -al /usr/bin/python*

    echo "---- Python Version ----"
    python3.9 --version
    echo "---- END Python Version ----"
    curl https://bootstrap.pypa.io/pip/get-pip.py -o get-pip.py
    python3.9 get-pip.py
    echo "---- pip Version ----"
    python3.9 -m pip --version
    echo "---- END pip Version ----"

    # Workaround for python bug:  AttributeError: module 'collections' has no attribute 'Callable'
    python3.9 -m pip uninstall -y pyreadline
    python3.9 -m pip install pyreadline3
    python3.9 -m pip uninstall -y nose
    python3.9 -m pip install nose-py3
else
    echo "Uninstalling default Python version ..."
    apt-get remove -y -–auto-remove python3-pip

    echo "Defaulting to and installing Python 3.9 ..."
    apt-get install -y software-properties-common
    add-apt-repository ppa:deadsnakes/ppa
    apt-cache policy python3.9
    apt-get update
    apt-get install -y python3.9 python3.9-distutils

    ls -al /usr/bin/python*

    echo "---- Python Version ----"
    python3.9 --version
    echo "---- END Python Version ----"
    curl https://bootstrap.pypa.io/pip/get-pip.py -o get-pip.py
    python3.9 get-pip.py
    echo "---- pip Version ----"
    python3.9 -m pip --version
    echo "---- END pip Version ----"

    # Workaround for python bug:  AttributeError: module 'collections' has no attribute 'Callable'
    python3.9 -m pip uninstall -y pyreadline
    python3.9 -m pip install pyreadline3
    python3.9 -m pip uninstall -y nose
    python3.9 -m pip install nose-py3
fi

echo "Installing additional tools & libraries..."
apt-get install -y gcc make zlib1g-dev libc-dev libffi-dev g++ libxml2 libxml2-dev libxslt-dev libcurl4-openssl-dev libssl-dev libgnutls28-dev
