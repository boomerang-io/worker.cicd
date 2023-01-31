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
    echo "Installing Python 3..."
    apt-get install -y python3-pip
    # apk add python3 python3-dev py3-pip

    pip3 install --upgrade pip

    # Workaround for python bug:  AttributeError: module 'collections' has no attribute 'Callable'
    pip3 uninstall -y nose
    pip3 install -U nose --no-binary :all:
else
    echo "Defaulting to and installing Python 3..."
    apt-get install -y python3-pip
    # apk add python3 python3-dev py3-pip

    pip3 install --upgrade pip

    # Workaround for python bug:  AttributeError: module 'collections' has no attribute 'Callable'
    pip3 uninstall -y nose
    pip3 install -U nose --no-binary :all:
fi

echo "Installing additional tools & libraries..."
apt-get install -y gcc make zlib1g-dev libc-dev libffi-dev g++ libxml2 libxml2-dev libxslt-dev libcurl4-openssl-dev libssl-dev libgnutls28-dev
# apk add gcc g++ libffi libffi-dev
