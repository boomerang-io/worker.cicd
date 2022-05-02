#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

LANGUAGE_VERSION=$1
ART_URL=$2
ART_USER=$3
ART_PASSWORD=$4

# Get the scope of the package from the name field
SCOPE=$(node -pe "require('./package.json').name" | cut -d/ -f1);

if [[ $SCOPE != @* ]]; then
    echo "Package name must include a scope e.g. '@scope/my-package'"
    echo "The scope should be unique to your organization/team"
    exit 95
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

curl -k -v -u $ART_USER:$ART_PASSWORD $ART_URL/api/npm/boomeranglib-npm/auth/"${SCOPE:1}" -o .npmrc
npm publish --registry $ART_URL/api/npm/boomeranglib-npm/ $DEBUG_OPTS
RESULT=$?
if [ $RESULT -ne 0 ]; then
    exit 89
fi