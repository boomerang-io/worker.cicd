#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_TOOL=$1
CYPRESS_INSTALL_BINARY=$2

DEBUG_OPTS=
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    DEBUG_OPTS+="--verbose"
fi

if [ "$BUILD_TOOL" != "npm" ] && [ "$BUILD_TOOL" != "yarn" ]; then
    echo "build tool not specified, defaulting to npm..."
    BUILD_TOOL="npm"
fi

BUILD_TOOL="yarn"
echo "Using build tool $BUILD_TOOL"

if [ "$CYPRESS_INSTALL_BINARY" == "undefined" ]; then
    echo "Defaulting Cypress Install Binary to 0..."
    CYPRESS_INSTALL_BINARY=0
else
    echo "Setting Cypress Install Binary to $CYPRESS_INSTALL_BINARY..."
fi

if [ "$BUILD_TOOL" == "yarn" ]; then
    echo "Running YARN install..."
    yarn install $DEBUG_OPTS
    RESULT=$?
    if [ $RESULT -ne 0 ] ; then
        exit 89
    fi
fi

## Determine which npm command to use
if  [ "$BUILD_TOOL" == "npm" ]; then
    if [ -e 'package-lock.json' ]; then
        echo "Running NPM ci..."
        npm ci $DEBUG_OPTS
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    else
        echo "Running NPM install..."
        npm install $DEBUG_OPTS
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    fi
fi
