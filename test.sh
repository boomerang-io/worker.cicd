#!/bin/bash

SCRIPT=$(node -pe "require('./package.json').scripts.test")
echo $SCRIPT

if [[ -d "./node_modules/mocha" && "$SCRIPT" == *react-scripts* || "$SCRIPT" == *jest* ]]; then
    echo "yes"
else
    echo "no"
fi
