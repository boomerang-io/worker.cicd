#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Initialize Dependencies '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_LANGUAGE_VERSION=$1

if [ "$DEBUG" == "true" ]; then
    echo "DEBUG - Script input variables..."
    echo "BUILD_LANGUAGE_VERSION=$BUILD_LANGUAGE_VERSION"
fi

if [ "$BUILD_LANGUAGE_VERSION" == "2" ]; then
    # echo "Installing Python 2 ..."
    # apk add python python-dev py-pip
    #
    # pip install --upgrade pip
    echo "Python 2 no longer supported ..."
    exit 89
elif [ "$BUILD_LANGUAGE_VERSION" == "3" ]; then
    echo "Installing Python 3 ..."
    apk add python3 python3-dev py3-pip

    pip3 install --upgrade pip
else
    echo "Defaulting to and installing Python 3 ..."
    apk add python3 python3-dev py3-pip

    pip3 install --upgrade pip
fi

echo "Installing additional tools & libraries ..."
apk add gcc g++ libffi libffi-dev
