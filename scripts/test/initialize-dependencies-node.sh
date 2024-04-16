#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

LANGUAGE_VERSION=$1
BUILD_TOOL=$2
CYPRESS_INSTALL_BINARY=$3


# Install specified version of Node.js
echo "Using NVM with Node version: $LANGUAGE_VERSION"
unset npm_config_prefix
source ~/.nvm/nvm.sh

# Install configured version of Node.js via nvm if present
if [ "$LANGUAGE_VERSION" == "undefined" ] || [ "$LANGUAGE_VERSION" == "" ]; then
    # Set Node.js version
    LANGUAGE_VERSION=16
fi

nvm install $LANGUAGE_VERSION
nvm use $LANGUAGE_VERSION

[[ "$BUILD_TOOL" == "npm" ]] && USE_NPM=true || USE_NPM=false
[[ "$BUILD_TOOL" == "yarn" ]] && USE_YARN=true || USE_YARN=false
[[ "$BUILD_TOOL" == "pnpm" ]] && USE_PNPM=true || USE_PNPM=false

if [ "$USE_NPM" == false ] && [ "$USE_YARN" == false ] && [ "$USE_PNPM" == false ]; then
    echo "build tool not specified, defaulting to 'npm'..."
    BUILD_TOOL="npm"
fi

echo "Using build tool $BUILD_TOOL"

echo "Running with nvm..."
unset npm_config_prefix
source ~/.nvm/nvm.sh
nvm use $LANGUAGE_VERSION

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

# Set Husky hook flag
echo "Disabling Husky hooks..."
export HUSKY=0

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
