#!/bin/bash

#( printf '\n'; printf '%.0s-' {1..30}; printf ' Static Code Analysis '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_TOOL=$1
VERSION_NAME=$2
SONAR_URL=$3
SONAR_APIKEY=$4
SONAR_GATEID=2
COMPONENT_ID=$5
COMPONENT_NAME=$6
ART_REGISTRY_HOST=$7
ART_REPO_ID=$8
ART_REPO_USER=$9
ART_REPO_PASSWORD=${10}

if [ "$DEBUG" == "true" ]; then
    echo "DEBUG - Script input variables..."
    echo "BUILD_TOOL=$BUILD_TOOL"
    echo "VERSION_NAME=$VERSION_NAME"
    echo "SONAR_URL=$SONAR_URL"
    echo "SONAR_APIKEY=*****"
    echo "SONAR_GATEID=$SONAR_GATEID"
    echo "COMPONENT_ID=$COMPONENT_ID"
    echo "COMPONENT_NAME=$COMPONENT_NAME"
    echo "ART_REGISTRY_HOST=$ART_REGISTRY_HOST"
    echo "ART_REPO_ID=$ART_REPO_ID"
    echo "ART_REPO_USER=$ART_REPO_USER"
    echo "ART_REPO_PASSWORD=*****"
fi

# Create Artifactory references for library download
PIP_CONF=~/.pip.conf
cat >> $PIP_CONF <<EOL
[global]
extra-index-url=https://$ART_REPO_USER:$ART_REPO_PASSWORD@$ART_REGISTRY_HOST/artifactory/api/pypi/$ART_REPO_ID/simple
[install]
extra-index-url=https://$ART_REPO_USER:$ART_REPO_PASSWORD@$ART_REGISTRY_HOST/artifactory/api/pypi/$ART_REPO_ID/simple
EOL

# Export pip config home
export PIP_CONFIG_FILE=$PIP_CONF

if [ -f requirements.txt ]; then
  echo "Using requirements.txt file found in project to install dependencies"
  python3.9 -m pip install -r requirements.txt
  RESULT=$?
  if [ $RESULT -ne 0 ] ; then
    exit 89
  fi
else
  echo "No requirements.txt file found to install dependencies via pip"
fi

curl --noproxy $NO_PROXY -I --insecure $SONAR_URL/about
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$( echo "$SONAR_URL/api/projects/create?&project=$COMPONENT_ID&name="$COMPONENT_NAME"" | sed 's/ /%20/g' )"
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$SONAR_URL/api/qualitygates/select?projectKey=$COMPONENT_ID&gateId=$SONAR_GATEID"

# Dependency for sonarscanner
apt-get install -y openjdk-8-jdk

# Install unzip
apt-get install -y unzip

# TODO: should be a CICD system property
curl --insecure -o /opt/sonarscanner.zip -L https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856.zip
# curl --insecure -o /opt/sonarscanner.zip -L https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-3.3.0.1492.zip
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

echo "coverage:"
find . -iname "*.py" -print | xargs coverage run
coverage xml
echo "==== XML ===="
ls -al *.xml
echo "==== XML ===="
nosetests -sv --with-xunit --xunit-file=$REPORT_HOME/nosetests.xml --with-xcoverage --xcoverage-file=$REPORT_HOME/coverage.xml
echo "----------------------------------------------------------------------------------------------"

echo "nosetests.xml:"
cat $REPORT_HOME/nosetests.xml
echo "----------------------------------------------------------------------------------------------"

echo "coverage.xml:"
cat $REPORT_HOME/coverage.xml
echo "----------------------------------------------------------------------------------------------"

SONAR_FLAGS="$SONAR_FLAGS -Dsonar.python.pylint.reportPaths=$REPORT_HOME/pylintrp.txt -Dsonar.python.xunit.reportPath=$REPORT_HOME/nosetests.xml -Dsonar.python.coverage.reportPath=$REPORT_HOME/coverage.xml -Dsonar.exclusions=**/bin/**,**/pylintrp.txt,**/coverage.xml,**/nosetests.xml"
$SONAR_HOME/bin/sonar-scanner -Dsonar.host.url=$SONAR_URL -Dsonar.login=$SONAR_APIKEY -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion=$VERSION_NAME -Dsonar.verbose=true -Dsonar.scm.disabled=true -Dsonar.sources=. -Dsonar.language=py $SONAR_FLAGS
