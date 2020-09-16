#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_TOOL=$1

DEBUG_OPTS=
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    DEBUG_OPTS+="--verbose"
fi

if [ "$BUILD_TOOL" == "npm" ] || [ "$BUILD_TOOL" == "yarn" ]; then
    if [ -e 'yarn.lock' ]; then
        echo "Running YARN install..."
        yarn install DEBUG_OPTS
    elif [ -e 'package-lock.json' ]; then
        echo "Running NPM ci..."
        npm ci DEBUG_OPTS
    else
        echo "Running NPM install..."
        npm install DEBUG_OPTS
    fi
else
    exit 99
fi

SCRIPT=$(node -pe "require('./package.json').scripts.publish");
if [ "$SCRIPT" != "undefined" ]; then
    if [ "$BUILD_TOOL" == "npm" ]; then
        npm publish
    elif [ "$BUILD_TOOL" == "yarn" ]; then
        yarn publish
    else
        exit 97
    fi
else
    exit 97
fi
