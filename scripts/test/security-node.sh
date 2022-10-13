#!/bin/bash

#( printf '\n'; printf '%.0s-' {1..30}; printf ' Security Test - Node '; printf '%.0s-' {1..30}; printf '\n\n' )

COMPONENT_NAME=${1}
VERSION_NAME=${2}
ART_URL=${3}
ART_REPO_USER=${4}
ART_REPO_PASSWORD=${5}
ASOC_APP_ID=${6}
ASOC_LOGIN_KEY_ID=${7}
ASOC_LOGIN_SECRET=${8}
ASOC_CLIENT_CLI=${9}
ASOC_JAVA_RUNTIME=${10}
SHELL_DIR=${11}
TEST_DIR=${12}

# Install unzip 
apt-get -y update && apt-get --no-install-recommends -y install unzip

# Download ASOC CLI
echo "SAClientUtil File: $ART_URL/$ASOC_CLIENT_CLI"
echo "Creds: $ART_REPO_USER:$ART_REPO_PASSWORD"
curl --noproxy "$NO_PROXY" --insecure -u $ART_REPO_USER:$ART_REPO_PASSWORD "$ART_URL/$ASOC_CLIENT_CLI" -o $TEST_DIR/SAClientUtil.zip

# Unzip ASOC CLI
unzip $TEST_DIR/SAClientUtil.zip -d $TEST_DIR
rm -f $TEST_DIR/SAClientUtil.zip
SAC_DIR=`ls -d $TEST_DIR/SAClientUtil*`
echo "SAC_DIR=$SAC_DIR"
mv $SAC_DIR $TEST_DIR/SAClientUtil

# Set ASOC CLI path
export ASOC_PATH=$TEST_DIR/SAClientUtil
# export ASOC_PATH=$TEST_DIR/data/SAClientUtil
export PATH="${ASOC_PATH}:${ASOC_PATH}/bin:${PATH}"
echo "PATH=$PATH"

# Set ASOC memory configuration
# echo "-Xmx4g" | tee -a $ASOC_PATH/config/cli.config
# cat $ASOC_PATH/config/cli.config

# # Switch to test path
# cd $TEST_DIR

# Set ASOC project path
export PROJECT_PATH=`pwd`
# export PROJECT_PATH=$TEST_DIR
echo "PROJECT_PATH=$PROJECT_PATH"

# Create ASOC configuration file
cp ${SHELL_DIR}/test/security-node.xml $ASOC_PATH/appscan-config.xml
xmlstarlet ed --inplace -u "Configuration/Targets/Target/@path" -v "$PROJECT_PATH" $ASOC_PATH/appscan-config.xml

# Generate ASOC IRX file
export APPSCAN_OPTS="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT"
echo "APPSCAN_OPTS=$APPSCAN_OPTS"
$ASOC_PATH/bin/appscan.sh prepare -c $ASOC_PATH/appscan-config.xml -n ${COMPONENT_NAME}_${VERSION_NAME}.irx

# If IRX file not created exit with error
if [ ! -f "${COMPONENT_NAME}_${VERSION_NAME}.irx" ]; then
  echo "IRX file not created"
  exit 128
fi

# Start ASOC Static Analyzer scan
echo "ASOC App ID: $ASOC_APP_ID"
echo "ASOC Login Key ID: $ASOC_LOGIN_KEY_ID"
echo "ASOC Login Secret ID: $ASOC_LOGIN_SECRET"

$ASOC_PATH/bin/appscan.sh api_login -u $ASOC_LOGIN_KEY_ID -P $ASOC_LOGIN_SECRET
ASOC_SCAN_ID=$($ASOC_PATH/bin/appscan.sh queue_analysis -a $ASOC_APP_ID -f ${COMPONENT_NAME}_${VERSION_NAME}.irx -n ${COMPONENT_NAME}_${VERSION_NAME} | tail -n 1)
echo "ASOC Scan ID: $ASOC_SCAN_ID"

# If no ASOC Scan ID returned exit with error
if [ -z "$ASOC_SCAN_ID" ]; then
  echo "Scan not started"
  exit 129
fi

# Wait for ASOC scan to complete
START_SCAN=`date +%s`
RUN_SCAN=true
while [ "$($ASOC_PATH/bin/appscan.sh status -i $ASOC_SCAN_ID)" != "Ready" ] && [ "$RUN_SCAN" == "true" ]; do
  NOW=`date +%s`
  DIFF=`expr $NOW - $START_SCAN`
  if [ $DIFF -gt 3600 ]; then
    echo "Timed out waiting for ASOC job to complete [$DIFF/3600]"
    RUN_SCAN=false
  else
    echo "ASOC job execution not completed ... waiting 15 seconds they retrying [$DIFF/3600]"
    sleep 15
  fi
done

# If scan not completed exit with error
if [ "$RUN_SCAN" == "false" ]; then
  echo "Scan failed"
  exit 130
fi

# Retrieve ASOC execution summary
$ASOC_PATH/bin/appscan.sh info -i $ASOC_SCAN_ID -json >> ASOC_SUMMARY_${COMPONENT_NAME}_${VERSION_NAME}.json
curl -T ASOC_SUMMARY_${COMPONENT_NAME}_${VERSION_NAME}.json "https://tools.boomerangplatform.net/artifactory/boomerang/software/asoc/ASOC_SUMMARY_${COMPONENT_NAME}_${VERSION_NAME}_${ASOC_SCAN_ID}.json" --insecure -u admin:WwwWulaWwHH!

# Retrieve ASOC report
$ASOC_PATH/bin/appscan.sh get_result -d ASOC_SCAN_RESULTS_${COMPONENT_NAME}_${VERSION_NAME}.zip -i $ASOC_SCAN_ID -t ZIP
curl -T ASOC_SCAN_RESULTS_${COMPONENT_NAME}_${VERSION_NAME}.zip "https://tools.boomerangplatform.net/artifactory/boomerang/software/asoc/ASOC_SCAN_RESULTS_${COMPONENT_NAME}_${VERSION_NAME}_${ASOC_SCAN_ID}.zip" --insecure -u admin:WwwWulaWwHH!
