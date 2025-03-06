#!/bin/bash

#( printf '\n'; printf '%.0s-' {1..30}; printf ' Static Code Analysis '; printf '%.0s-' {1..30}; printf '\n\n' )

SONAR_URL=$1
SONAR_APIKEY=$2
SONAR_GATEID=2
COMPONENT_ID=$3
COMPONENT_NAME=$4
VERSION_NAME=$5

if [ "$DEBUG" == "true" ]; then
    echo "DEBUG - Script input variables..."
    echo "SONAR_URL=$SONAR_URL"
    echo "SONAR_APIKEY=*****"
    echo "COMPONENT_ID=$COMPONENT_ID"
    echo "COMPONENT_NAME=$COMPONENT_NAME"
    echo "VERSION_NAME=$VERSION_NAME"
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

SONAR_FLAGS="$SONAR_FLAGS -Dsonar.exclusions=**/bin/**"
$SONAR_HOME/bin/sonar-scanner -Dsonar.host.url=$SONAR_URL -Dsonar.token=$SONAR_APIKEY -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion="$VERSION_NAME" -Dsonar.verbose=true -Dsonar.scm.disabled=true -Dsonar.sources=. $SONAR_FLAGS
