#!/bin/bash

#( printf '\n'; printf '%.0s-' {1..30}; printf ' Static Code Analysis '; printf '%.0s-' {1..30}; printf '\n\n' )

LANGUAGE_VERSION=$1
BUILD_TOOL=$2
VERSION_NAME=$3
SONAR_URL=$4
SONAR_APIKEY=$5
SONAR_GATEID=2
COMPONENT_ID=$6
COMPONENT_NAME=$7
ART_URL=$8
ART_USER=$9
ART_PASSWORD=${10}

# Install configured version of Node.js via nvm if present
# Also install JDK correctly depending on what the underlying Linux image is
# Ubuntu or Alpine
if [ "$LANGUAGE_VERSION" != "undefined" ] && [ "$LANGUAGE_VERSION" != "" ]; then
    # Dependency for sonarscanner
    export ENV DEBIAN_FRONTEND noninteractive
    apt-get -y update
    apt-get --no-install-recommends -y install openjdk-8-jdk unzip

    # Set Node.js version
    echo "Running with nvm..."
    unset npm_config_prefix
    source ~/.nvm/nvm.sh
    nvm use $LANGUAGE_VERSION
else
    # Dependency for sonarscanner
    apk add openjdk8
fi

[[ "$BUILD_TOOL" == "npm" ]] && USE_NPM=true || USE_NPM=false
[[ "$BUILD_TOOL" == "yarn" ]] && USE_YARN=true || USE_YARN=false
[[ "$BUILD_TOOL" == "pnpm" ]] && USE_PNPM=true || USE_PNPM=false

if [ "$USE_NPM" == false ] && [ "$USE_YARN" == false ] && [ "$USE_PNPM" == false ]; then
    echo "build tool not specified, defaulting to 'npm'..."
    BUILD_TOOL="npm"
fi

# Set JS heap space
export NODE_OPTIONS="--max-old-space-size=8192"

# Check SonarQube
curl --noproxy $NO_PROXY -I --insecure $SONAR_URL/about
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$( echo "$SONAR_URL/api/projects/create?&project=$COMPONENT_ID&name="$COMPONENT_NAME"" | sed 's/ /%20/g' )"
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$SONAR_URL/api/qualitygates/select?projectKey=$COMPONENT_ID&gateId=$SONAR_GATEID"

# Install sonar-scanner
curl --insecure -o /opt/sonarscanner.zip -u $ART_USER:$ART_PASSWORD $ART_URL/boomerang/software/sonarqube/sonar-scanner-cli-4.7.0.2747-linux.zip
unzip -o /opt/sonarscanner.zip -d /opt
SONAR_FOLDER=`ls /opt | grep sonar-scanner`
SONAR_HOME=/opt/$SONAR_FOLDER
if [ "$DEBUG" == "true" ]; then
    SONAR_FLAGS="-Dsonar.verbose=true"
else
    SONAR_FLAGS=
fi

# Run linting script

SCRIPT=$(node -pe "require('./package.json').scripts.lint");
if [[ "$SCRIPT" != "undefined" ]]; then
    npm run lint
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.eslint.reportPaths=lint-report.json"
    ls -al lint-report.json
    echo "SONAR_FLAGS=$SONAR_FLAGS"
fi

SRC_FOLDER=
if [ -d "dist" ]; then
    echo "Source folder 'dist' exists."
    SRC_FOLDER=src
elif [ -d "src" ]; then
    echo "Source folder 'src' exists."
    SRC_FOLDER=src
else
    echo "Source folder 'src' does not exist - defaulting to root folder of project and will scan all sub-folders."
    SRC_FOLDER=.
fi

# Set Node.js bin path
NODE_PATH=$(which node)
echo "NODE_PATH=$NODE_PATH"

$SONAR_HOME/bin/sonar-scanner -Dsonar.host.url=$SONAR_URL -Dsonar.sources=$SRC_FOLDER -Dsonar.login=$SONAR_APIKEY -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion=$VERSION_NAME -Dsonar.nodejs.executable=$NODE_PATH -Dsonar.scm.disabled=true -Dsonar.javascript.node.maxspace=8192 $SONAR_FLAGS

EXIT_CODE=$?
echo "EXIT_CODE=$EXIT_CODE"

exit $EXIT_CODE
