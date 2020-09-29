#!/bin/bash

#( printf '\n'; printf '%.0s-' {1..30}; printf ' Static Code Analysis '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_TOOL=$1
VERSION_NAME=$2
SONAR_URL=$3
SONAR_APIKEY=$4
SONAR_GATEID=2
COMPONENT_ID=$5
COMPONENT_NAME=$6

# fail fast if testing script or build tool is not present
SCRIPT=$(node -pe "require('./package.json').scripts.test");
if [[ "$SCRIPT" == "undefined" ]]; then
    exit 95
fi

[[ "$BUILD_TOOL" == "npm" ]] && USE_NPM=true || USE_NPM=false
[[ "$BUILD_TOOL" == "yarn" ]] && USE_YARN=true || USE_YARN=false

if [[ "$USE_NPM" == false ]] && [[ "$USE_YARN" == false ]]; then
    exit 99
fi


curl --noproxy $NO_PROXY -I --insecure $SONAR_URL/about
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$( echo "$SONAR_URL/api/projects/create?&project=$COMPONENT_ID&name="$COMPONENT_NAME"" | sed 's/ /%20/g' )"
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$SONAR_URL/api/qualitygates/select?projectKey=$COMPONENT_ID&gateId=$SONAR_GATEID"

# Dependency for sonarscanner
apk add openjdk8

curl --insecure -o /opt/sonarscanner.zip -L https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-3.3.0.1492.zip
unzip -o /opt/sonarscanner.zip -d /opt
SONAR_FOLDER=`ls /opt | grep sonar-scanner`
SONAR_HOME=/opt/$SONAR_FOLDER
if [[ "$DEBUG" == "true" ]]; then
    SONAR_FLAGS="-Dsonar.verbose=true"
else
    SONAR_FLAGS=
fi

if [[ -d "./node_modules/jest" ]]; then
    TEST_REPORTER="jest-sonar-reporter"
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.testExecutionReportPaths=test-report.xml"
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.tests=src"
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.test.inclusions=**/*.spec.js"
    if [[ "$USE_NPM" == true ]]; then
        echo "Installing $TEST_REPORTER"
        COMMAND_ARGS="-- --testResultsProcessor $TEST_REPORTER"
        npm i -D $TEST_REPORTER
    elif [[ "$USE_YARN" == true ]]; then
        echo "Installing $TEST_REPORTER"
        COMMAND_ARGS="--testResultsProcessor $TEST_REPORTER"
        yarn add -D $TEST_REPORTER
    fi
fi

if [[ "$USE_NPM" == true ]]; then
    npm test $COMMAND_ARGS
elif [[ "$USE_YARN" == true ]]; then
    yarn test $COMMAND_ARGS
fi

SONAR_FLAGS="$SONAR_FLAGS -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info"

$SONAR_HOME/bin/sonar-scanner -Dsonar.host.url=$SONAR_URL -Dsonar.sources=src -Dsonar.login=$SONAR_APIKEY -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion=$VERSION_NAME -Dsonar.scm.disabled=true $SONAR_FLAGS
