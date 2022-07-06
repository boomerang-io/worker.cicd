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
if [ "$LANGUAGE_VERSION" != "undefined" ] && [ "$LANGUAGE_VERSION" != "" ]; then

    # Install specified version of Node.js
    echo "Using NVM with Node version: $LANGUAGE_VERSION"
    unset npm_config_prefix
    source ~/.nvm/nvm.sh
    nvm install $LANGUAGE_VERSION
    nvm use $LANGUAGE_VERSION

else
    # TODO: Move these into the base node builder image
    # Cannot run if using NVM as thats on Ubuntu
    apk add --no-cache gcc g++ make libc6-compat libc-dev lcms2-dev libpng-dev automake autoconf libtool python && apk add --no-cache fftw-dev build-base --repository http://dl-3.alpinelinux.org/alpine/edge/testing --repository http://dl-3.alpinelinux.org/alpine/edge/main && apk add --no-cache nodejs nodejs-npm --repository http://dl-3.alpinelinux.org/alpine/edge/main
fi

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
    if [[ $node_version =~ $pattern ]]; then
        major_version=${BASH_REMATCH[1]}
        if [[ $major_version -gt 12 ]]; then
            npm install --global pnpm@7
        else
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
echo "Cache enabled: $USE_CACHE"

if [ "$USE_CACHE" == true ]; then
  echo "Checking cache folder..."
  if [ ! -d "/workflow/cache/modules" ]; then
    echo "Creating cache folder..."
    mkdir -p /workflow/cache/modules
  fi

  if [ -d "/workflow/cache/modules" ]; then
      # echo "Check .pnpm-store folder exists..."
      # mkdir -p /workflow/cache/modules/.pnpm-store
      echo "Setting cache..."
      if [ "$USE_NPM" == true ]; then
          npm config set cache /workflow/cache/modules
      fi
      if [ "$USE_YARN" == true ]; then
          yarn config set cache-folder /workflow/cache/modules
      fi
      if [ "$USE_PNPM" == true ]; then
          pnpm config set store-dir /workflow/cache/modules
      fi
  fi
fi
