#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Initialize Dependencies '; printf '%.0s-' {1..30}; printf '\n\n' )

export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

LANGUAGE_VERSION=$1
BUILD_TOOL=$2
ART_URL=$3
ART_USER=$4
ART_PASSWORD=$5

if [ "$BUILD_TOOL" != "npm" ] && [ "$BUILD_TOOL" != "yarn" ]; then
    exit 99
fi

if [ "$LANGUAGE_VERSION" != "undefined" ] && [ ! -z "$LANGUAGE_VERSION" ]; then
    unset npm_config_prefix
    source ~/.nvm/nvm.sh
    nvm install $LANGUAGE_VERSION
    nvm run node --version
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
