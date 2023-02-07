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

# Fail fast if testing script is not present
SCRIPT=$(node -pe "require('./package.json').scripts.test");
if [[ "$SCRIPT" == "undefined" ]]; then
    echo "'test' script not defined in the package.json file"
    exit 95
fi

# Dependency for sonarscanner
export ENV DEBIAN_FRONTEND noninteractive
apt-get -y update
apt-get install -y openjdk-11-jdk

echo "Running with nvm..."
unset npm_config_prefix
source ~/.nvm/nvm.sh

# Install configured version of Node.js via nvm if present
if [ "$LANGUAGE_VERSION" == "undefined" ] || [ "$LANGUAGE_VERSION" == "" ]; then
    # Set Node.js version
    LANGUAGE_VERSION=12
fi

nvm use $LANGUAGE_VERSION

[[ "$BUILD_TOOL" == "npm" ]] && USE_NPM=true || USE_NPM=false
[[ "$BUILD_TOOL" == "yarn" ]] && USE_YARN=true || USE_YARN=false
[[ "$BUILD_TOOL" == "pnpm" ]] && USE_PNPM=true || USE_PNPM=false

if [[ "$USE_NPM" == false ]] && [[ "$USE_YARN" == false ]] && [[ "$USE_PNPM" == false ]]; then
    echo "Build tool not specified, defaulting to 'npm'..."
    BUILD_TOOL="npm"
fi

echo "Using build tool $BUILD_TOOL"

# Set JS heap space
export NODE_OPTIONS="--max-old-space-size=8192"

# Check SonarQube
curl --noproxy $NO_PROXY -I --insecure $SONAR_URL/about
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$( echo "$SONAR_URL/api/projects/create?&project=$COMPONENT_ID&name="$COMPONENT_NAME"" | sed 's/ /%20/g' )"
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$SONAR_URL/api/qualitygates/select?projectKey=$COMPONENT_ID&gateId=$SONAR_GATEID"

# Install sonar-scanner
# TODO: should be a CICD system property
# Install sonar-scanner
echo "Installing sonar-scanner"
echo "$ART_URL/boomerang/software/sonarqube/sonar-scanner-cli-4.8.0.2856.zip"
curl --insecure -o /opt/sonarscanner.zip -L -u $ART_USER:$ART_PASSWORD $ART_URL/boomerang/software/sonarqube/sonar-scanner-cli-4.8.0.2856.zip
unzip -o /opt/sonarscanner.zip -d /opt
SONAR_FOLDER=`ls /opt | grep sonar-scanner`
SONAR_HOME=/opt/$SONAR_FOLDER
if [ "$DEBUG" == "true" ]; then
    SONAR_FLAGS="-Dsonar.verbose=true"
else
    SONAR_FLAGS=
fi

# Check that jest exists and that it is being used in the script, either directly or through CRA
if [[ -d "./node_modules/jest" && "$SCRIPT" == *react-scripts* || "$SCRIPT" == *jest* ]]; then
    TEST_REPORTER="jest-sonar-reporter"
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.testExecutionReportPaths=test-report.xml"
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.tests=src"

    # Support Typscript and other common naming standards
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.test.inclusions=**/*.test.tsx,**/*.test.ts,**/*.test.jsx,**/*.test.js,**/*.spec.tsx,**/*.spec.ts,**/*.spec.js,**/*.spec.tsx"
    if [[ "$USE_NPM" == true ]]; then
        echo "Installing $TEST_REPORTER"
        COMMAND_ARGS="-- --testResultsProcessor $TEST_REPORTER"
        npm i -D $TEST_REPORTER
    elif [[ "$USE_YARN" == true ]]; then
        echo "Installing $TEST_REPORTER"
        COMMAND_ARGS="--testResultsProcessor $TEST_REPORTER"
        yarn add -D $TEST_REPORTER
    elif [[ "$USE_PNPM" == true ]]; then
        echo "Installing $TEST_REPORTER"
        COMMAND_ARGS="-- --testResultsProcessor $TEST_REPORTER"
        pnpm i -D $TEST_REPORTER
    fi
fi

# Check that vitest exists and that it is being used in the script
if [[ -d "./node_modules/vitest" && "$SCRIPT" == *vitest* ]]; then
    TEST_REPORTER="vitest-sonar-reporter"
    TEST_REPORTER_PATH="nodes_modules/vitest-sonar-reporter"
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.testExecutionReportPaths=test-report.xml"
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.tests=src"

    # Support Typscript and other common naming standards
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.test.inclusions=**/*.test.tsx,**/*.test.ts,**/*.test.jsx,**/*.test.js,**/*.spec.tsx,**/*.spec.ts,**/*.spec.js,**/*.spec.tsx"
    if [[ "$USE_NPM" == true ]]; then
        COMMAND_ARGS="-- --reporter $TEST_REPORTER_PATH --outputFile test-report.xml"
        if [[ -d "./node_modules/vitest-sonar-reporter" ]]; then
            echo "Installing $TEST_REPORTER"
            npm i -D $TEST_REPORTER
        fi
    elif [[ "$USE_YARN" == true ]]; then
        COMMAND_ARGS="--reporter $TEST_REPORTER_PATH --outputFile test-report.xml"
        if [[ -d "./node_modules/vitest-sonar-reporter" ]]; then
            echo "Installing $TEST_REPORTER"
            yarn add -D $TEST_REPORTER
        fi
    elif [[ "$USE_PNPM" == true ]]; then
        COMMAND_ARGS="-- --reporter $TEST_REPORTER_PATH --outputFile test-report.xml"
        if [[ -d "./node_modules/vitest-sonar-reporter" ]]; then
            echo "Installing $TEST_REPORTER"
            pnpm i -D $TEST_REPORTER
        fi
    fi
fi

if [[ "$USE_NPM" == true ]]; then
    # npm clean-install
    npm test $COMMAND_ARGS
elif [[ "$USE_YARN" == true ]]; then
    yarn test $COMMAND_ARGS
elif [[ "$USE_PNPM" == true ]]; then
    pnpm test $COMMAND_ARGS
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

SONAR_FLAGS="$SONAR_FLAGS -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info"

$SONAR_HOME/bin/sonar-scanner -Dsonar.host.url=$SONAR_URL -Dsonar.sources=$SRC_FOLDER -Dsonar.login=$SONAR_APIKEY -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion=$VERSION_NAME -Dsonar.nodejs.executable=$NODE_PATH -Dsonar.scm.disabled=true -Dsonar.javascript.node.maxspace=8192 $SONAR_FLAGS

EXIT_CODE=$?
echo "EXIT_CODE=$EXIT_CODE"

exit $EXIT_CODE
