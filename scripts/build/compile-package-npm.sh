#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_TOOL=$1

DEBUG_OPTS=
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    DEBUG_OPTS+="--verbose"
fi

"pnpm-lock.yaml"

if [ "$BUILD_TOOL" == "npm" ] || [ "$BUILD_TOOL" == "yarn" ] || [ "$BUILD_TOOL" == "pnpm" ]; then
    if [ -e 'package-lock.json' ]; then
        echo "Running npm ci..."
        npm ci DEBUG_OPTS
    elif [ -e 'yarn.lock' ]; then
        echo "Running yarn install..."
        yarn install DEBUG_OPTS
    elif [ -e 'pnpm-lock.yaml' ]; then
        echo "Running pnpm install..."
        pnpm install DEBUG_OPTS
    else
       echo "No lockfile found. Defaulting to npm."
       echo "Running npm install..."
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
    elif [ "$BUILD_TOOL" == "pnpm" ]; then
        pnpm publish
    else
        exit 97
    fi
else
    exit 97
fi
