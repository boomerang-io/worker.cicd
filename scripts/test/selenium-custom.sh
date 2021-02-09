#!/bin/bash

#( printf '\n'; printf '%.0s-' {1..30}; printf ' Automated Web Testing via Selenium Custom'; printf '%.0s-' {1..30}; printf '\n\n' )

TEAM_NAME=${1}
COMPONENT_NAME=${2}
VERSION_NAME=${3}
PROPERTY_FILE=${4}
PROPERTY_KEY=${5}
PROPERTY_VALUE=${6}
REPORT_FOLDER=${7}
ART_URL=${8}
ART_USER=${9}
ART_PASSWORD=${10}
SHELL_DIR=${11}
TEST_DIR=${12}

cd $TEST_DIR

echo "PROPERTY_FILE=$PROPERTY_FILE"
echo "PROPERTY_KEY=$PROPERTY_KEY"
echo "PROPERTY_VALUE=$PROPERTY_VALUE"

touch ${PROPERTY_FILE}.resolved

while read LINE
do
  KEY=`echo $LINE | cut -d'=' -f1`
  if [ "$KEY" == "$PROPERTY_KEY" ]; then
    echo "Key found [$KEY] ... replacing value with [$PROPERTY_VALUE]"
    echo "$KEY=$PROPERTY_VALUE" >> ${PROPERTY_FILE}.resolved
  else
    echo "$LINE" >> ${PROPERTY_FILE}.resolved
  fi
done < $PROPERTY_FILE

echo "http.proxyHost=$PROXY_HOST" >> ${PROPERTY_FILE}.resolved
echo "http.proxyPort=$PROXY_PORT" >> ${PROPERTY_FILE}.resolved
echo "https.proxyHost=$PROXY_HOST" >> ${PROPERTY_FILE}.resolved
echo "https.proxyPort=$PROXY_PORT" >> ${PROPERTY_FILE}.resolved

mv -f ${PROPERTY_FILE}.resolved ${PROPERTY_FILE}

apk add maven

MAVEN_PROXY_IGNORE=`echo "$NO_PROXY" | sed -e 's/ //g' -e 's/\"\,\"/\|/g' -e 's/\,\"/\|/g' -e 's/\"$//' -e 's/\,/\|/g'`
export MAVEN_OPTS="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttp.nonProxyHosts='$MAVEN_PROXY_IGNORE' -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT -Dhttps.nonProxyHosts='$MAVEN_PROXY_IGNORE'"

export USE_PROXY=true

env http.proxyHost=$PROXY_HOST http.proxyPort=$PROXY_PORT https.proxyHost=$PROXY_HOST https.proxyPort=$PROXY_PORT mvn clean test

if [ -d "$REPORT" ]; then
  echo "Zip Selenium report and upload to Artifactory"
  apk add zip
  zip -r SeleniumReport.zip $REPORT
  curl -T SeleniumReport.zip "${ART_URL}/boomerang/ci/repos/${TEAM_NAME}/${COMPONENT_NAME}/${VERSION_NAME}/SeleniumReport.zip" --insecure -u $ART_USER:$ART_PASSWORD
fi
