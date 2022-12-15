#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Initialize Dependencies '; printf '%.0s-' {1..30}; printf '\n\n' )

# apk add curl curl-dev wget

BUILD_LANGUAGE_VERSION=$1

if [ "$BUILD_LANGUAGE_VERSION" == "17" ]; then
    echo "Language version specified. Installing Java 17..."
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
    echo "export PATH=$JAVA_HOME/bin:$PATH" >> ~/.profile
    source ~/.profile
elif [ "$BUILD_LANGUAGE_VERSION" == "11" ]; then
    echo "Language version specified. Installing Java 11..."
    # apk --no-cache add openjdk11 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community
    export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
    echo "export PATH=$JAVA_HOME/bin:$PATH" >> ~/.profile
elif [ "$BUILD_LANGUAGE_VERSION" == "12" ]; then
    echo "Language version specified. Unfortunately we do not yet support Java 12..."
    # apk --no-cache add openjdk11 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community
else
    echo "No language version specified. Defaulting to Java 8..."
    export JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk
    echo "export PATH=$JAVA_HOME/bin:$PATH" >> ~/.profile
    # apk add openjdk8
fi
