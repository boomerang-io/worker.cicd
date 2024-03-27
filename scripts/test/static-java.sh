#!/bin/bash

#( printf '\n'; printf '%.0s-' {1..30}; printf ' Static Code Analysis '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_TOOL=$1
VERSION_NAME=$2
SONAR_URL=$3
SONAR_APIKEY=$4
SONAR_GATEID=2
COMPONENT_ID=$5
COMPONENT_NAME=$6
SONAR_EXCLUSIONS=$7

curl --noproxy $NO_PROXY -I --insecure $SONAR_URL/about
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$( echo "$SONAR_URL/api/projects/create?&project=$COMPONENT_ID&name="$COMPONENT_NAME"" | sed 's/ /%20/g' )"
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$SONAR_URL/api/qualitygates/select?projectKey=$COMPONENT_ID&gateId=$SONAR_GATEID"

if [ "$BUILD_TOOL" == "maven" ]; then
    echo "Testing with Maven"    
    MAVEN_OPTS="-Xmx1024m -XX:MaxMetaspaceSize=128m"
    if [ "$HTTP_PROXY" != "" ]; then
        # Swap , for |
        MAVEN_PROXY_IGNORE=`echo "$NO_PROXY" | sed -e 's/ //g' -e 's/\"\,\"/\|/g' -e 's/\,\"/\|/g' -e 's/\"$//' -e 's/\,/\|/g'`
        MAVEN_OPTS+="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttp.nonProxyHosts='$MAVEN_PROXY_IGNORE' -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT -Dhttps.nonProxyHosts='$MAVEN_PROXY_IGNORE'"
    fi
    export MAVEN_OPTS=$MAVEN_OPTS
    echo "MAVEN_OPTS=$MAVEN_OPTS"
    DEBUG_OPTS=
    if [ "$DEBUG" == "true" ]; then
        echo "Enabling debug logging..."
        DEBUG_OPTS+="--debug -Dsonar.verbose=true"
    fi
    echo "DEBUG_OPTS=$DEBUG_OPTS"

    export SONAR_SCANNER_EXCLUSIONS
    if [ "$SONAR_EXCLUSIONS" != "" ]; then
        echo "Setting Sonar Exclusions to: $SONAR_EXCLUSIONS"
        export SONAR_SCANNER_EXCLUSIONS="-Dsonar.exclusions=$SONAR_EXCLUSIONS"
    fi
    echo "SONAR_SCANNER_EXCLUSIONS=$SONAR_SCANNER_EXCLUSIONS"

    export SONAR_SCANNER_OPTS="-Xmx1024m"

    # Set java environment varaibles as per initialize-dependencies-java.sh
    source ~/.profile
    echo "JAVA_HOME (compile): $JAVA_HOME"
    echo "PATH (compile): $PATH"

    # Compile source
    mvn clean compile -Dversion.name=$VERSION_NAME $DEBUG_OPTS $MAVEN_OPTS -DskipTests=true -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true -Dmaven.wagon.http.ssl.ignore.validity.dates=true

    # Set to Java 17 for Sonarqube
    echo "Set to Java 17 for Sonarqube..."
    echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk" >> ~/.profile
    echo "export PATH=/usr/lib/jvm/java-17-openjdk/bin:$PATH" >> ~/.profile

    source ~/.profile
    echo "JAVA_HOME (sonar): $JAVA_HOME"
    echo "PATH (sonar): $PATH"

    # Run Sonarqube
    mvn sonar:sonar -DskipTests=true -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true -Dmaven.wagon.http.ssl.ignore.validity.dates=true -Dsonar.login=$SONAR_APIKEY -Dsonar.host.url=$SONAR_URL -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion=$VERSION_NAME -Dsonar.verbose=true -Dsonar.scm.disabled=true $SONAR_SCANNER_EXCLUSIONS

elif [ "$BUILD_TOOL" == "gradle" ]; then
    echo "ERROR: Gradle not implemented yet."
    exit 1
else
    echo "ERROR: no build tool specified."
    exit 1
fi
