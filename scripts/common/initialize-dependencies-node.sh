#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Initialize Dependencies '; printf '%.0s-' {1..30}; printf '\n\n' )

LANGUAGE_VERSION=$1
BUILD_TOOL=$2
ART_URL=$3
ART_USER=$4
ART_PASSWORD=$5

 
if [ "$BUILD_TOOL" != "npm" ] && [ "$BUILD_TOOL" != "yarn" ]; then
    echo "Build tool not specified, defaulting to npm..."
    BUILD_TOOL="npm"
fi

echo "Using build tool $BUILD_TOOL"

if [ "$LANGUAGE_VERSION" != "undefined" ]; then

    # Install yarn if set as the build tool in Ubuntu path
    if [ "$BUILD_TOOL" == "yarn" ]; then
        npm install --global yarn
    fi

    # Install specified version of Node.js
    echo "Using NVM with Node version: $LANGUAGE_VERSION"
    unset npm_config_prefix
    source ~/.nvm/nvm.sh
    nvm install $LANGUAGE_VERSION
    nvm use $LANGUAGE_VERSION

else
    # TODO: Move these into the base node builder image
    # Cannot run if using NVM as thats on Ubuntu
    apk add --no-cache gcc g++ make libc6-compat libc-dev lcms2-dev libpng-dev automake autoconf libtool python yarn && apk add --no-cache fftw-dev build-base --repository http://dl-3.alpinelinux.org/alpine/edge/testing --repository http://dl-3.alpinelinux.org/alpine/edge/main && apk add --no-cache nodejs nodejs-npm --repository http://dl-3.alpinelinux.org/alpine/edge/main
    export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
fi

curl -k -u $ART_USER:$ART_PASSWORD $ART_URL/api/npm/boomeranglib-npm/auth/boomerang -o ~/.npmrc
if [[ $? -ne 0 ]]; then
    echo "Error retrieving .npmrc for scoped packages from the platform"
fi

if [ "$DEBUG" == "true" ]; then
    cat ~/.npmrc
fi

echo "Versions:"
if [ "$BUILD_TOOL" == "yarn" ]; then echo "  Yarn: $(yarn --version)"; fi
if [ "$BUILD_TOOL" == "npm" ]; then echo "  npm: $(npm --version)"; fi
echo "  Node: $(node --version)"

if [ "$HTTP_PROXY" != "" ]; then
    if [ "$BUILD_TOOL" == "yarn" ]; then
        echo "Setting YARN Proxy Settings..."
        yarn config set proxy http://$PROXY_HOST:$PROXY_PORT
        yarn config set https-proxy http://$PROXY_HOST:$PROXY_PORT
        yarn config set no-proxy $NO_PROXY
    else
        echo "Setting NPM Proxy Settings..."
        npm config set proxy http://$PROXY_HOST:$PROXY_PORT
        npm config set https-proxy http://$PROXY_HOST:$PROXY_PORT
        npm config set no-proxy $NO_PROXY
    fi
fi

if [ -d "/cache" ]; then
    echo "Setting cache..."
    mkdir -p /cache/modules
    ls -ltr /cache
    if [ "$BUILD_TOOL" == "yarn" ]; then
        yarn config set cache-folder /cache/modules
    else
        npm config set cache /cache/modules
    fi
fi
