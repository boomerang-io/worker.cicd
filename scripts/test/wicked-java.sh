#!/bin/bash
TEAMNAME=$1
COMPONENTNAME=$2
VERSION=$3
ARTIFACTORY_URL=$4
ARTIFACTORY_USER=$5
ARTIFACTORY_PASSWORD=$6

# add required 7zip for jar unzip
apk add p7zip

# download the jar dependencies into target/dependency
mvn dependency:copy-dependencies

# wicked scan
echo "Starting Wicked Scan..."
mkdir reports
wicked-cli -s target/dependency -o reports #-p cicdservice
#reports/unzipfolder_scan-results/Scan-Report.json

# upload the report to artifactory
echo "Uploading reports to ${ARTIFACTORY_URL}/boomerang/ci/reports/$TEAMNAME/$COMPONENTNAME/$VERSION/"
# for file in /folder/path/*
# do
#   curl -u username:password -T ${file} http://www.example.com/folder/${file}
# done
# find /folder/path/ -name '*' -type f -exec curl -u USERNAME:PASSWORD -T {} http://www.example.com/folder/ \;
curl -T "reports/*" "${ARTIFACTORY_URL}/boomerang/ci/reports/$TEAMNAME/$COMPONENTNAME/$VERSION/" -u ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD}

# TODO trigger API to parse the report and save summary and link to in DB