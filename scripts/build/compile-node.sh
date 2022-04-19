#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

LANGUAGE_VERSION=$1
BUILD_TOOL=$2
BUILD_SCRIPT=$3

if [ "$BUILD_TOOL" != "npm" ] && [ "$BUILD_TOOL" != "yarn" ]; then
    echo "Build tool not specified, defaulting to npm..."
    BUILD_TOOL="npm"
fi

echo "Using build tool $BUILD_TOOL"

if [ -z "$BUILD_SCRIPT" ]; then
    echo "Defaulting npm script to 'build'..."
    BUILD_SCRIPT=build
else
    echo "Setting npm script to $BUILD_SCRIPT..."
fi
CYPRESS_INSTALL_BINARY=$4
if [ "$DEBUG" == "true" ]; then
    echo "DEBUG - Script input variables..."
    echo "LANGUAGE_VERSION=$LANGUAGE_VERSION"
    echo "BUILD_SCRIPT=$BUILD_SCRIPT"
    echo "CYPRESS_INSTALL_BINARY=$CYPRESS_INSTALL_BINARY"
fi

NVM_OPTS=
if [ "$LANGUAGE_VERSION" != "undefined" ]; then
    echo "Running with NVM..."
    unset npm_config_prefix
    source ~/.nvm/nvm.sh
fi

DEBUG_OPTS=
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    DEBUG_OPTS+="--verbose"
fi

# Set JS heap space
export NODE_OPTIONS="--max-old-space-size=8192"

if [ -z "$CYPRESS_INSTALL_BINARY" ]; then
    echo "Defaulting Cypress Install Binary to 0..."
    CYPRESS_INSTALL_BINARY=0
else
    echo "Setting Cypress Install Binary to $CYPRESS_INSTALL_BINARY..."
fi

if [ "$BUILD_TOOL" == "yarn" ]; then
    echo "Running YARN install..."
    # cd remix-hello-yarn
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

# This needs to be checking for undefined as thats whats returned by the node command
SCRIPT=$(node -pe "require('./package.json').scripts.$BUILD_SCRIPT");
if [ "$SCRIPT" != "undefined" ]; then
    if [ "$BUILD_TOOL" == "npm" ]; then
        npm run build $DEBUG_OPTS
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    elif [ "$BUILD_TOOL" == "yarn" ]; then

        # Don't pass through DEBUG_OPTS as they will be appended the script that is run 
        yarn build 
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    else
        exit 97
    fi
else
    # exit 97
    echo "npm script ($BUILD_SCRIPT) not defined in package.json. Skipping..."
fi
