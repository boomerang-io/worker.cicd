#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Initialize Dependencies '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_LANGUAGE_VERSION=$1

if [ "$DEBUG" == "true" ]; then
    echo "DEBUG - Script input variables..."
    echo "BUILD_LANGUAGE_VERSION=$BUILD_LANGUAGE_VERSION"
fi

if [ "$BUILD_LANGUAGE_VERSION" == "2" ]; then
    echo "Installing Python 2 ..."
    apk add python python-dev py-pip
elif [ "$BUILD_LANGUAGE_VERSION" == "3" ]; then
    echo "Installing Python 3 ..."
    apk add python3 python3-dev
else
    echo "Defaulting to and installing Python 3 ..."
    apk add python3 python3-dev
fi

apk add gcc g++