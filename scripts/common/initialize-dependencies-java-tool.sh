#!/bin/bash

BUILD_TOOL=$1
BUILD_TOOL_VERSION=$2

if [ "$BUILD_TOOL" == "maven" ]; then
    echo "Installing maven ..."
    apk add maven
    # TODO update to use build tool if specified
elif [ "$BUILD_TOOL" == "gradle" ]; then
    echo "Installing gradle ..."
    apk add gradle
else
    exit 99
fi
