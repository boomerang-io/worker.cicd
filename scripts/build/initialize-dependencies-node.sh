#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

LANGUAGE_VERSION=$1
BUILD_TOOL=$2
CYPRESS_INSTALL_BINARY=$3

[[ "$BUILD_TOOL" == "npm" ]] && USE_NPM=true || USE_NPM=false
[[ "$BUILD_TOOL" == "yarn" ]] && USE_YARN=true || USE_YARN=false
[[ "$BUILD_TOOL" == "pnpm" ]] && USE_PNPM=true || USE_PNPM=false

if [ "$USE_NPM" == false ] && [ "$USE_YARN" == false ] && [ "$USE_PNPM" == false ]; then
    echo "Build tool not specified, defaulting to 'npm'..."
    BUILD_TOOL="npm"
fi

echo "Using build tool $BUILD_TOOL"

if [ -z "$BUILD_SCRIPT" ]; then
    echo "Build script not specified, defaulting to 'build'..."
    BUILD_SCRIPT=build
else
    echo "Setting build script to $BUILD_SCRIPT..."
fi

if [ "$DEBUG" == "true" ]; then
    echo "DEBUG - Script input variables..."
    echo "LANGUAGE_VERSION=$LANGUAGE_VERSION"
    echo "BUILD_SCRIPT=$BUILD_SCRIPT"
    echo "CYPRESS_INSTALL_BINARY=$CYPRESS_INSTALL_BINARY"
fi

# Install configured version of Node.js via nvm if present
if [ "$LANGUAGE_VERSION" != "undefined" ]; then
    echo "Running with nvm..."
    unset npm_config_prefix
    source ~/.nvm/nvm.sh
    nvm use $LANGUAGE_VERSION
fi

DEBUG_OPTS=
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    DEBUG_OPTS+="--verbose"
fi

# Set JS heap space
export NODE_OPTIONS="--max-old-space-size=8192"

if [ -z "$CYPRESS_INSTALL_BINARY" ]; then
    echo "Defaulting Cypress install binary to 0..."
    CYPRESS_INSTALL_BINARY=0
else
    echo "Setting Cypress install binary to $CYPRESS_INSTALL_BINARY..."
fi

# Determine how to install dependencies based on package manager and lockfile
if  [ "$USE_NPM" == true ]; then
    if [ -e 'package-lock.json' ]; then
        echo "Running npm ci..."
        npm ci $DEBUG_OPTS
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    else
        echo "No lockfile found. Defaulting to 'npm install'."
        echo "Running npm install..."
        npm install $DEBUG_OPTS
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    fi
fi

if [ "$USE_YARN" == true ]; then
    echo "Running yarn install..."
    yarn install $DEBUG_OPTS
    RESULT=$?
    if [ $RESULT -ne 0 ] ; then
        exit 89
    fi
fi

if [ "$USE_PNPM" == true ]; then
    echo "Running pnpm install..."
    pnpm install $DEBUG_OPTS
fi
