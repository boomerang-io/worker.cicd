#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_TOOL=$1
CYPRESS_INSTALL_BINARY=$2

DEBUG_OPTS=
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    DEBUG_OPTS+="--verbose"
fi

if [ "$CYPRESS_INSTALL_BINARY" == "undefined" ]; then
    echo "Defaulting Cypress Install Binary to 0..."
    CYPRESS_INSTALL_BINARY=0
else
    echo "Setting Cypress Install Binary to $CYPRESS_INSTALL_BINARY..."
fi

if [ "$BUILD_TOOL" == "npm" ] || [ "$BUILD_TOOL" == "yarn" ] || [ "$BUILD_TOOL" == "pnpm" ]; then
    if [ -e 'package-lock.json' ]; then
        echo "Running npm ci..."
        npm ci $DEBUG_OPTS
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    elif [ -e 'yarn.lock' ]; then
        echo "Running yarn install..."
        yarn install $DEBUG_OPTS
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    elif [ -e 'pnpm-lock.yaml' ]; then
        echo "Running pnpm install..."
        pnpm install $DEBUG_OPTS
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    else
        echo "No lockfile found. Defaulting to npm."
        echo "Running npm install..."
        npm install $DEBUG_OPTS
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    fi
else
    exit 99
fi
