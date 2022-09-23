#!/bin/bash

WSS_UNIFIED_AGENT_DOWNLOAD_URL=$1

echo 'Installing Whitesource Dependencies...'

# Download Whitesource Unified Agent JAR
echo "Downloading Whitesource Unified Agent from $WSS_UNIFIED_AGENT_DOWNLOAD_URL"
curl -LJO $WSS_UNIFIED_AGENT_DOWNLOAD_URL

# Install Java requried by Whitesource Unified Agent. 
# refer https://docs.mend.io/bundle/unified_agent/page/getting_started_with_the_unified_agent.html
if ! [ -x "$(command -v java)" ]; then
  echo 'Java is not installed.'
  if [ -x "$(command -v apk)" ]; then
  echo 'Install openjdk8 via apk on alpine'
  apk add openjdk8
  fi
  
  if [ -x "$(command -v apt-get)" ]; then
  echo 'Install openjdk8 via apt-get on ubuntu'
  apt-get --no-install-recommends -y install openjdk-8-jdk
  fi
else
  echo 'Java is already installed.'
fi
java -version