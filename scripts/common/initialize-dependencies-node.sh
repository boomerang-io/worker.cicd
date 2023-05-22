#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Initialize Dependencies '; printf '%.0s-' {1..30}; printf '\n\n' )

LANGUAGE_VERSION=$1
BUILD_TOOL=$2
ART_URL=$3
ART_USER=$4
ART_PASSWORD=$5
CACHE_ENABLED=$6

[[ "$BUILD_TOOL" == "npm" ]] && USE_NPM=true || USE_NPM=false
[[ "$BUILD_TOOL" == "yarn" ]] && USE_YARN=true || USE_YARN=false
[[ "$BUILD_TOOL" == "pnpm" ]] && USE_PNPM=true || USE_PNPM=false

if [ "$USE_NPM" == false ] && [ "$USE_YARN" == false ] && [ "$USE_PNPM" == false ]; then
    echo "Build tool not specified, defaulting to 'npm'..."
    BUILD_TOOL="npm"
fi

echo "Using build tool $BUILD_TOOL"

# Install configured version of Node.js via nvm if present
if [ "$LANGUAGE_VERSION" == "undefined" ] || [ "$LANGUAGE_VERSION" == "" ]; then
    # Set Node.js version
    LANGUAGE_VERSION=12
fi

# Install Node.js
echo "Using NVM with Node version: $LANGUAGE_VERSION"
unset npm_config_prefix
source ~/.nvm/nvm.sh
nvm install $LANGUAGE_VERSION
nvm use $LANGUAGE_VERSION

# Install node-pre-gyp
npm install --global node-pre-gyp

# Install yarn if set as the build tool
if [ "$USE_YARN" == true ]; then
    npm install --global yarn
fi

# Install pnpm if set as the build tool
if [ "$USE_PNPM" == true ]; then
    # check the version of Node.js that is running to determine what version of pnpm to install
    # pnpm 7 does not support Node.js v12
    version_pattern="^v([0-9]+)\.([0-9]+)\.([0-9]+)$"
    node_version=$(node -v)
    echo "Node version=$node_version"
    if [[ $node_version =~ $version_pattern ]]; then
        major_version=${BASH_REMATCH[1]}
        echo "Node major version=$major_version"
        if [[ $major_version -gt 12 ]]; then
            echo "Installing pnpm v7"
            npm install --global pnpm@7
        else
            echo "Installing pnpm v6"
            npm install --global pnpm@6
        fi
    fi
fi

curl -k -u $ART_USER:$ART_PASSWORD $ART_URL/api/npm/boomeranglib-npm/auth/boomerang -o ~/.npmrc
if [[ $? -ne 0 ]]; then
    echo "Error retrieving .npmrc for scoped packages from the platform"
fi

if [ "$DEBUG" == "true" ]; then
    cat ~/.npmrc
fi

echo "Versions:"
if [ "$USE_NPM" == true ]; then echo "  npm: $(npm --version)"; fi
if [ "$USE_YARN" == true ]; then echo "  yarn: $(yarn --version)"; fi
if [ "$USE_PNPM" == true ]; then echo "  pnpm: $(pnpm --version)"; fi

echo "  Node: $(node --version)"

if [ "$HTTP_PROXY" != "" ]; then
    if [ "$USE_NPM" == true ]; then
        echo "Setting npm proxy settings..."
        npm config set proxy http://$PROXY_HOST:$PROXY_PORT
        npm config set https-proxy http://$PROXY_HOST:$PROXY_PORT
        npm config set no-proxy $NO_PROXY
    fi
    if [ "$USE_YARN" == true ]; then
        echo "Setting yarn proxy settings..."
        yarn config set proxy http://$PROXY_HOST:$PROXY_PORT
        yarn config set https-proxy http://$PROXY_HOST:$PROXY_PORT
        yarn config set no-proxy $NO_PROXY
    fi
    if [ "$USE_PNPM" == true ]; then
        echo "Setting pnpm proxy settings..."
        pnpm config set proxy http://$PROXY_HOST:$PROXY_PORT
        pnpm config set https-proxy http://$PROXY_HOST:$PROXY_PORT
        pnpm config set no-proxy $NO_PROXY
    fi
fi

[[ "$CACHE_ENABLED" == "true" ]] && USE_CACHE=true || USE_CACHE=false
echo "Package Cache enabled: $USE_CACHE"

if [ "$USE_CACHE" == true ]; then
  echo "Checking package cache folder..."
  if [ ! -d "/workspace/workflow/cache/modules" ]; then
    echo "Creating package cache folder..."
    mkdir -p /workspace/workflow/cache/modules
  fi

  echo "Checking package cache size..."
  du -h --max-depth=1 /workspace/workflow/cache/modules

  if [ -d "/workspace/workflow/cache/modules" ]; then
      # echo "Check .pnpm-store folder exists..."
      # mkdir -p /workspace/workflow/cache/modules/.pnpm-store
      echo "Setting package cache..."
      if [ "$USE_NPM" == true ]; then
          npm config set cache /workspace/workflow/cache/modules
      fi
      if [ "$USE_YARN" == true ]; then
          yarn config set cache-folder /workspace/workflow/cache/modules
      fi
      if [ "$USE_PNPM" == true ]; then
          pnpm config set store-dir /workspace/workflow/cache/modules
      fi
  fi
fi
