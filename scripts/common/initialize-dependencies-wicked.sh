#!/bin/bash

# wicked cli require JDK8 and nodejs
# check jdk8 exist
if [ -f /usr/lib/jvm/java-1.8-openjdk ]
then
    echo "Using exist openjdk8..."
    export JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk
    echo "export PATH=$JAVA_HOME/bin:$PATH" >> ~/.profile
else
    echo "Installing openjdk8..."
    apk add openjdk8
fi

# install wicked cli
cat >> ~/.npmrc <<EOL
@wicked:registry=https://na.artifactory.swg-devops.com/artifactory/api/npm/wicked-npm-local/
//na.artifactory.swg-devops.com/artifactory/api/npm/wicked-npm-local/:_password="QUtDcDVkSzRvUXVZNUVqS3RnV0hiQm1YSEVOR3RycEJaa3h3c05Ya2VQS1VnaTE0NVNjSGsxTEM0\nWGlYV2ZSUzFRdXZIYVJVeQ=="
//na.artifactory.swg-devops.com/artifactory/api/npm/wicked-npm-local/:username=mingxias@cn.ibm.com
//na.artifactory.swg-devops.com/artifactory/api/npm/wicked-npm-local/:email=mingxias@cn.ibm.com
//na.artifactory.swg-devops.com/artifactory/api/npm/wicked-npm-local/:always-auth=true
EOL

npm install @wicked/cli -g