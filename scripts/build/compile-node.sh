#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

LANGUAGE_VERSION=$1
BUILD_SCRIPT=$2

# Install configured version of Node.js via nvm if present
if [ "$LANGUAGE_VERSION" != "undefined" ]; then
    echo "Running with nvm..."
    unset npm_config_prefix
    source ~/.nvm/nvm.sh
    nvm use $LANGUAGE_VERSION
fi

if [ -z "$BUILD_SCRIPT" ]; then
    echo "Build script not specified, defaulting to 'build'..."
    BUILD_SCRIPT=build
else
    echo "Setting build script to $BUILD_SCRIPT..."
fi

# This needs to be checking for undefined as thats whats returned by the node command
SCRIPT=$(node -pe "require('./package.json').scripts.$BUILD_SCRIPT");
if [ "$SCRIPT" != "undefined" ]; then
    npm run $BUILD_SCRIPT $DEBUG_OPTS
    RESULT=$?
    if [ $RESULT -ne 0 ] ; then
        exit 89
    fi
else
    # Allow Node.js components to not have a build step
    echo "npm script ($BUILD_SCRIPT) not defined in the package.json file. Skipping..."
fi

