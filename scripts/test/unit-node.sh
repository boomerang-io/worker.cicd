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

# Fail fast if both test and lint scripts are not present
TEST_SCRIPT=$(node -pe "require('./package.json').scripts.test");
LINT_SCRIPT=$(node -pe "require('./package.json').scripts.lint");
if [ "$TEST_SCRIPT" == "undefined" ] && [ "$LINT_SCRIPT" == "undefined" ]; then
    echo "'test' and 'lint' scripts are not defined in the package.json file. Running default scan from SonarQube."
fi

# Dependency for sonarscanner
export ENV DEBIAN_FRONTEND noninteractive
apt-get -y update
apt-get install -y openjdk-17-jdk

# Install unzip
apt-get install -y unzip

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
echo "Installing sonar-scanner"
echo "$ART_URL/boomerang/software/sonarqube/sonar-scanner-cli-4.8.0.2856.zip"
curl --insecure -o /opt/sonarscanner.zip -L -u $ART_USER:$ART_PASSWORD $ART_URL/boomerang/software/sonarqube/sonar-scanner-cli-4.8.0.2856.zip
unzip -o /opt/sonarscanner.zip -d /opt
SONAR_FOLDER=`ls /opt | grep sonar-scanner`
SONAR_HOME=/opt/$SONAR_FOLDER
SONAR_FLAGS=
if [ "$DEBUG" == "true" ]; then
    SONAR_FLAGS="-Dsonar.verbose=true"
fi

# Run 'test'
if [[ "$TEST_SCRIPT" != "undefined" ]]; then
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.testExecutionReportPaths=test-report.xml"
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.tests=src"
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.test.inclusions=**/*.test.tsx,**/*.test.ts,**/*.test.jsx,**/*.test.js,**/*.spec.tsx,**/*.spec.ts,**/*.spec.js,**/*.spec.tsx"
    UNIT_TEST_REPORT_NAME="test-report.xml"
    COMMAND_ARGS=""
    
    # Check that jest exists and that it is being used in the script, either directly or through CRA
    if [[ -d "./node_modules/jest" && "$TEST_SCRIPT" == *react-scripts* || "$TEST_SCRIPT" == *jest* ]]; then
        TEST_REPORTER="jest-sonar-reporter"
        COMMAND_ARGS="-- --coverage --testResultsProcessor $TEST_REPORTER"
        if [[ ! -d "./node_modules/jest-sonar-reporter" ]]; then
            if [[ "$USE_NPM" == true ]]; then
                echo "Installing $TEST_REPORTER"
                npm i -D $TEST_REPORTER
            elif [[ "$USE_YARN" == true ]]; then
                echo "Installing $TEST_REPORTER"
                yarn add -D $TEST_REPORTER
            elif [[ "$USE_PNPM" == true ]]; then
                echo "Installing $TEST_REPORTER"
                pnpm i -D $TEST_REPORTER
            fi
        fi
    fi

    # Check that vitest exists and that it is being used in the script
    if [[ -d "./node_modules/vitest" && "$TEST_SCRIPT" == *vitest* ]]; then
        COVERAGE_PROVIDER="c8"
        COVERAGE_REPORTER="lcov"
        TEST_REPORTER="vitest-sonar-reporter"
        COMMAND_ARGS="-- --coverage.enabled --reporter=$TEST_REPORTER --outputFile=$UNIT_TEST_REPORT_NAME --coverage.reporter=$COVERAGE_REPORTER --coverage.provider=$COVERAGE_PROVIDER"


        if [[ ! -d "./node_modules/$TEST_REPORTER" ]]; then
            if [[ "$USE_NPM" == true ]]; then
                echo "Installing $TEST_REPORTER"
                npm i -D $TEST_REPORTER
            elif [[ "$USE_YARN" == true ]]; then
                echo "Installing $TEST_REPORTER"
                yarn add -D $TEST_REPORTER
            elif [[ "$USE_PNPM" == true ]]; then
                echo "Installing $TEST_REPORTER"
                pnpm i -D $TEST_REPORTER
            fi
        fi

        VITEST_VERSION=$(node -pe "require('./package.json').devDependencies.vitest");
        COVERAGE_PROVIDER_DEP="@vitest/coverage-c8@$VITEST_VERSION"
        if [[ ! -d "./node_modules/$COVERAGE_PROVIDER_DEP" ]]; then
            if [[ "$USE_NPM" == true ]]; then
                echo "Installing $COVERAGE_PROVIDER_DEP"
                npm i -D $COVERAGE_PROVIDER_DEP
            elif [[ "$USE_YARN" == true ]]; then
                echo "Installing $COVERAGE_PROVIDER_DEP"
                yarn add -D $COVERAGE_PROVIDER_DEP
            elif [[ "$USE_PNPM" == true ]]; then
                echo "Installing $COVERAGE_PROVIDER_DEP"
                pnpm i -D $COVERAGE_PROVIDER_DEP
            fi
        fi
    fi

    npm test $COMMAND_ARGS

    COVERAGE_REPORT=coverage/lcov.info
    SONAR_FLAGS="$SONAR_FLAGS -Dsonar.javascript.lcov.reportPaths=$COVERAGE_REPORT"
    ls -al $COVERAGE_REPORT
    cat $COVERAGE_REPORT
    echo "SONAR_FLAGS=$SONAR_FLAGS"
fi

# Run 'lint'
if [[ "$LINT_SCRIPT" != "undefined" ]]; then
    ESLINT_DEP=$(node -pe "require('./package.json').dependencies.eslint");
    ESLINT_DEV_DEP=$(node -pe "require('./package.json').devDependencies.eslint");
    if [[ "$ESLINT_DEP" != "undefined" ]] || [[ "$ESLINT_DEV_DEP" != "undefined" ]]; then
        LINT_REPORT=lint-report.json
        npm run lint -- -f json -o $LINT_REPORT
        SONAR_FLAGS="$SONAR_FLAGS -Dsonar.eslint.reportPaths=$LINT_REPORT"
        ls -al $LINT_REPORT
    fi
    echo "SONAR_FLAGS=$SONAR_FLAGS"
fi

# Set SonarQube scanning exclusions
SONAR_EXCLUSIONS=-Dsonar.exclusions=**/node_modules/**
# Place setter for new IF statement to handle user specified exclusions
# SONAR_EXCLUSIONS="$SONAR_EXCLUSIONS,$USER_EXCLUSIONS"
echo "SONAR_EXCLUSIONS=$SONAR_EXCLUSIONS"

SRC_FOLDER=
if [ -d "dist" ]; then
    echo "Source folder 'dist' exists."
    SRC_FOLDER=dist
elif [ -d "src" ]; then
    echo "Source folder 'src' exists."
    SRC_FOLDER=src
else
    echo "Source folder 'src' does not exist - defaulting to the current folder and will scan all sub-folders."
    SRC_FOLDER=.

     # Using root location as src folder means we will have a clash with worker.cicd folders so let's exclude those too
    echo "Append worker.cicd sub-folders to exclusions so they are not scanned by SonarQube."
    SONAR_EXCLUSIONS="$SONAR_EXCLUSIONS,/commands/**,/scripts/**"
    echo "SONAR_EXCLUSIONS=$SONAR_EXCLUSIONS"
fi
echo "SRC_FOLDER=$SRC_FOLDER"

# Set Node.js bin path
NODE_PATH=$(which node)
echo "NODE_PATH=$NODE_PATH"

$SONAR_HOME/bin/sonar-scanner -Dsonar.host.url=$SONAR_URL -Dsonar.sources=$SRC_FOLDER -Dsonar.login=$SONAR_APIKEY -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion=$VERSION_NAME -Dsonar.nodejs.executable=$NODE_PATH -Dsonar.scm.disabled=true -Dsonar.javascript.node.maxspace=8192 $SONAR_EXCLUSIONS $SONAR_FLAGS

EXIT_CODE=$?
echo "EXIT_CODE=$EXIT_CODE"

exit $EXIT_CODE
