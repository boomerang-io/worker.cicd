#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

ART_URL=$1
ART_USER=$2
ART_PASSWORD=$3

DEBUG_OPTS=
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    DEBUG_OPTS+="--verbose"
fi

# Get the scope of the package from the name field
SCOPE=$(node -pe "require('./package.json').name" | cut -d/ -f1);

if [[ $SCOPE != @* ]]; then
    echo "Package name must include a scope e.g. '@project/my-package'"
    exit 97
fi

curl -k -v -u $ART_USER:$ART_PASSWORD $ART_URL/api/npm/boomeranglib-npm/auth/"${SCOPE:1}" -o .npmrc
npm publish --registry $ART_URL/api/npm/boomeranglib-npm/ $DEBUG_OPTS
RESULT=$?
if [ $RESULT -ne 0 ]; then
    exit 89
fi