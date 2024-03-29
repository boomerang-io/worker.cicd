#!/bin/bash

#( printf '\n'; printf '%.0s-' {1..30}; printf ' Static Code Analysis '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_TOOL=$1
VERSION_NAME=$2
SONAR_URL=$3
SONAR_APIKEY=$4
SONAR_GATEID=2
COMPONENT_ID=$5
COMPONENT_NAME=$6
REQUIREMENTS_FILE=$7

if [ "$DEBUG" == "true" ]; then
    echo "DEBUG - Script input variables..."
    echo "BUILD_TOOL=$BUILD_TOOL"
    echo "VERSION_NAME=$VERSION_NAME"
    echo "SONAR_URL=$SONAR_URL"
    echo "SONAR_APIKEY=*****"
    echo "SONAR_GATEID=$SONAR_GATEID"
    echo "COMPONENT_ID=$COMPONENT_ID"
    echo "COMPONENT_NAME=$COMPONENT_NAME"
    echo "REQUIREMENTS_FILE=$REQUIREMENTS_FILE"
fi

if [ -z $REQUIREMENTS_FILE ]; then
  REQUIREMENTS_FILE="requirements.txt"
  echo "No requirements file input and use default requirements.txt."
# Install python dependencies
fi
if [ -f $REQUIREMENTS_FILE ]; then
  echo "Using $REQUIREMENTS_FILE file found in project to install dependencies"
  python3 -m pip install -r $REQUIREMENTS_FILE
  RESULT=$?
  if [ $RESULT -ne 0 ] ; then
    exit 89
  fi
else
  echo "No $REQUIREMENTS_FILE file found to install dependencies via pip"
fi

# Retrieve Sonarqube project and current gate
curl --noproxy $NO_PROXY -I --insecure $SONAR_URL/about
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$( echo "$SONAR_URL/api/projects/create?&project=$COMPONENT_ID&name="$COMPONENT_NAME"" | sed 's/ /%20/g' )"
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$SONAR_URL/api/qualitygates/select?projectKey=$COMPONENT_ID&gateId=$SONAR_GATEID"

# Dependency for sonarscanner
apt-get install -y openjdk-17-jdk

# Install unzip
apt-get install -y unzip

# TODO: should be a CICD system property
curl --insecure -o /opt/sonarscanner.zip -L https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856.zip
unzip -o /opt/sonarscanner.zip -d /opt
SONAR_FOLDER=`ls /opt | grep sonar-scanner`
SONAR_HOME=/opt/$SONAR_FOLDER
SONAR_FLAGS=
if [ "$DEBUG" == "true" ]; then
    SONAR_FLAGS="-Dsonar.verbose=true"
else
    SONAR_FLAGS=
fi

# Set report home folder
REPORT_HOME=..

pylint --generate-rcfile > .pylintrc
pylint --rcfile=.pylintrc $(find . -iname "*.py" -print) -r n --msg-template="{path}:{line}: [{msg_id}({symbol}), {obj}] {msg}" > $REPORT_HOME/pylintrp.txt

echo "pylintrp.txt:"
cat $REPORT_HOME/pylintrp.txt
echo "----------------------------------------------------------------------------------------------"

echo "pytest:"
pytest --cov=. --cov-report=xml:$REPORT_HOME/coverage.xml --junit-xml=$REPORT_HOME/pytests.xml
echo "----------------------------------------------------------------------------------------------"

echo "pytests.xml:"
cat $REPORT_HOME/pytests.xml
echo "----------------------------------------------------------------------------------------------"

echo "coverage.xml:"
cat $REPORT_HOME/coverage.xml
echo "----------------------------------------------------------------------------------------------"

SONAR_FLAGS="$SONAR_FLAGS -Dsonar.python.pylint.reportPaths=$REPORT_HOME/pylintrp.txt -Dsonar.python.xunit.reportPath=$REPORT_HOME/pytests.xml -Dsonar.python.coverage.reportPath=$REPORT_HOME/coverage.xml -Dsonar.exclusions=**/bin/**"
$SONAR_HOME/bin/sonar-scanner -Dsonar.host.url=$SONAR_URL -Dsonar.login=$SONAR_APIKEY -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion=$VERSION_NAME -Dsonar.verbose=true -Dsonar.scm.disabled=true -Dsonar.sources=. -Dsonar.language=py $SONAR_FLAGS