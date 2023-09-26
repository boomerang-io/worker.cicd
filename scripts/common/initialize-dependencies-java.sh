#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Initialize Dependencies '; printf '%.0s-' {1..30}; printf '\n\n' )

# apk add curl curl-dev wget

BUILD_LANGUAGE_VERSION=$1

if [ "$BUILD_LANGUAGE_VERSION" == "17" ]; then
    echo "Language version specified. Installing Java 17..."
    echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk" >> ~/.profile
    echo "export PATH=/usr/lib/jvm/java-17-openjdk/bin:$PATH" >> ~/.profile
elif [ "$BUILD_LANGUAGE_VERSION" == "11" ]; then
    echo "Language version specified. Installing Java 11..."
    echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk" >> ~/.profile
    echo "export PATH=/usr/lib/jvm/java-11-openjdk/bin:$PATH" >> ~/.profile
elif [ "$BUILD_LANGUAGE_VERSION" == "12" ]; then
    echo "Language version specified. Unfortunately we do not yet support Java 12. Reverting to Java 11."
    echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk" >> ~/.profile
    echo "export PATH=/usr/lib/jvm/java-11-openjdk/bin:$PATH" >> ~/.profile
else
    echo "No language version specified. Defaulting to Java 8..."
    echo "export JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk" >> ~/.profile
    echo "export PATH=/usr/lib/jvm/java-1.8-openjdk/bin:$PATH" >> ~/.profile
fi

source ~/.profile
echo "JAVA_HOME (compile): $JAVA_HOME"
echo "PATH (compile): $PATH"