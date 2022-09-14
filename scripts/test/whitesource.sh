#!/bin/bash

COMPONENT_ID=${1}
COMPONENT_NAME=${2}
COMPONENT_VERSION=${3} # Original Component Version including build number. e.g. 6.1.0-21
VERSION=${4} # Parsed version may or may not include build number based on parameter 'appendBuildNumber'
TEAM_NAME=${5}

echo "Component ID: $COMPONENT_ID"
echo "Component Name: $COMPONENT_NAME"
echo "Component Version: $COMPONENT_VERSION"
echo "Parsed Component Version: $VERSION"
echo "Team Name: $TEAM_NAME"

# Setting Environment Variables for Whitesource unified agent
# for Whitessource unified agent configuration, pls refer 
# https://docs.mend.io/bundle/unified_agent/page/unified_agent_configuration_parameters.html 
export WS_APIKEY=${6}
export WS_USERKEY=${7}
export WS_PRODUCTNAME=${8}
export WS_PRODUCTTOKEN=${9}
export WS_PROJECTNAME=${COMPONENT_NAME}
export WS_WSS_URL=${10}
export WS_GENERATESCANREPORT="true"
export WS_SCANREPORTFILENAMEFORMAT="static"
export WS_COMMANDTIMEOUT=3600

echo "Whitesource API Key: $WS_APIKEY"
echo "Whitesource User Key: $WS_USERKEY"
echo "Whitesource Product Name: $WS_PRODUCTNAME"
echo "Whitesource Product Token: $WS_PRODUCTTOKEN"
echo "Whitesource Project Name: $WS_PROJECTNAME"
echo "Whitesource WSS URL: $WS_WSS_URL"

# Run whitesource unified agent
java -jar wss-unified-agent.jar
ls -lh whitesource
if [ -f "whitesource/scan_report.json" ]; then
  echo "Whitesource Scan Report (scan_report.json) is generated."
  echo "Uploading Scan Report to SocreCard Ingest Service"
  SCORECARD_INGEST_URL="http://bmrg-cicd-services-ingestion/ingestion/whitesource?ciComponentId=$COMPONENT_ID&versionName=$COMPONENT_VERSION"
  curl -X POST $SCORECARD_INGEST_URL \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --data '@whitesource/scan_report.json'
else
  echo "Whitesource Scan Report (scan_report.json) is not generated."
fi