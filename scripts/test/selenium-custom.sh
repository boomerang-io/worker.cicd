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

urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C

    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            ' ') printf "%%20" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done

    LC_COLLATE=$old_lc_collate
}

# cd $TEST_DIR

echo "TEAM_NAME=$TEAM_NAME"
echo "COMPONENT_NAME=$COMPONENT_NAME"
echo "VERSION_NAME=$VERSION_NAME"
echo "PROPERTY_FILE=$PROPERTY_FILE"
echo "PROPERTY_KEY=$PROPERTY_KEY"
echo "PROPERTY_VALUE=$PROPERTY_VALUE"
echo "REPORT_FOLDER=$REPORT_FOLDER"
echo "ART_URL=$ART_URL"
echo "ART_USER=$ART_USER"
echo "ART_PASSWORD=*****"
echo "SHELL_DIR=$SHELL_DIR"
echo "TEST_DIR=$TEST_DIR"

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

if [ -d "$REPORT_FOLDER" ]; then
  echo "Zip Selenium report and upload to Artifactory"
  apk add zip
  zip -r SeleniumReport.zip $REPORT_FOLDER
  TEAM_NAME_ENCODED=$(urlencode "${TEAM_NAME}")
  echo "Uploading SeleniumReport.zip to ${ART_URL}/boomerang/ci/repos/${TEAM_NAME_ENCODED}/${COMPONENT_NAME}/${VERSION_NAME}/SeleniumReport.zip"
  curl -T SeleniumReport.zip "${ART_URL}/boomerang/ci/repos/${TEAM_NAME_ENCODED}/${COMPONENT_NAME}/${VERSION_NAME}/SeleniumReport.zip" --insecure -u $ART_USER:$ART_PASSWORD
fi
