#!/bin/bash
TEAMNAME=$1
COMPONENTNAME=$2
VERSION=$3
ARTIFACTORY_URL=$4
ARTIFACTORY_USER=$5
ARTIFACTORY_PASSWORD=$6

# install python to unzip whl
apk add python3

# unzip the whl into unzipfolder
mkdir unzipfolder
for file in  bdist_wheel/*
do
    python3 -m zipfile --extract "$file" unzipfolder
done

# wicked scan
echo "Starting Wicked Scan..."
mkdir reports
wicked-cli -s unzipfolder/ -o reports

# upload the report to artifactory
echo "Uploading reports to ${ARTIFACTORY_URL}/boomerang/ci/reports/$TEAMNAME/$COMPONENTNAME/$VERSION/"
curl -T "reports/*" "${ARTIFACTORY_URL}/boomerang/ci/reports/$TEAMNAME/$COMPONENTNAME/$VERSION/" -u ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD}

# trigger API to parse the report and save summary and link to in DB