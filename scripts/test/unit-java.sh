#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Static Code Analysis '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_TOOL=$1
VERSION_NAME=$2
SONAR_URL=$3
SONAR_APIKEY=$4
COMPONENT_ID=$5
COMPONENT_NAME=$6

if [ "$BUILD_TOOL" == "maven" ]; then
    echo "Testing with Maven"
    if [ "$HTTP_PROXY" != "" ]; then
        # Swap , for |
        MAVEN_PROXY_IGNORE=`echo "$NO_PROXY" | sed -e 's/ //g' -e 's/\"\,\"/\|/g' -e 's/\,\"/\|/g' -e 's/\"$//' -e 's/\,/\|/g'`
        export MAVEN_OPTS="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttp.nonProxyHosts='$MAVEN_PROXY_IGNORE' -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT -Dhttps.nonProxyHosts='$MAVEN_PROXY_IGNORE'"
    fi
    echo "MAVEN_OPTS=$MAVEN_OPTS"
    DEBUG_OPTS=
    if [ "$DEBUG" == "true" ]; then
        echo "Enabling debug logging..."
        DEBUG_OPTS+="--debug -Dsonar.verbose=true"
    fi
    echo "DEBUG_OPTS=$DEBUG_OPTS"

    # Set java environment varaibles as per initialize-dependencies-java.sh
    source ~/.profile
    echo "JAVA_HOME (compile): $JAVA_HOME"
    echo "PATH (compile): $PATH"

    # Compile source
    mvn clean test -Dversion.name=$VERSION_NAME $DEBUG_OPTS $MAVEN_OPTS

    # Set to Java 17 for Sonarqube
    echo "Set to Java 17 for Sonarqube..."
    echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk" >> ~/.profile
    echo "export PATH=/usr/lib/jvm/java-17-openjdk/bin:$PATH" >> ~/.profile

    source ~/.profile
    echo "JAVA_HOME (sonar): $JAVA_HOME"
    echo "PATH (sonar): $PATH"

    # Run Sonarqube
    mvn sonar:sonar -Dversion.name=$VERSION_NAME -Dsonar.login=$SONAR_APIKEY -Dsonar.host.url="$SONAR_URL" -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion=$VERSION_NAME -Dsonar.scm.disabled=true -Dsonar.junit.reportPaths=target/surefire-reports -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml $DEBUG_OPTS $MAVEN_OPTS

elif [ "$BUILD_TOOL" == "gradle" ]; then
    echo "ERROR: Gradle not implemented yet."
    exit 1
else
    echo "ERROR: no build tool specified."
    exit 1
fi
