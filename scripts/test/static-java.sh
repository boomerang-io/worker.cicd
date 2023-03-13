#!/bin/bash

#( printf '\n'; printf '%.0s-' {1..30}; printf ' Static Code Analysis '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_TOOL=$1
VERSION_NAME=$2
SONAR_URL=$3
SONAR_APIKEY=$4
SONAR_GATEID=2
COMPONENT_ID=$5
COMPONENT_NAME=$6
SONAR_EXCLUSIONS=

# Default to Java 17 for Sonarqube support
echo "Default to Java 17 for Sonarqube support ..."
echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk" >> ~/.profile
echo "export PATH=/usr/lib/jvm/java-17-openjdk/bin:$PATH" >> ~/.profile

# make java environment varaibles set by initialize-dependencies-java.sh effective.
source ~/.profile
echo "JAVA_HOME: $JAVA_HOME"
echo "PATH: $PATH"

export SONAR_SCANNER_EXCLUSIONS
if [ "$7" != "" ]; then
    echo "Setting Sonar Exclusions to: $7"
    SONAR_EXCLUSIONS=$7
    export SONAR_SCANNER_EXCLUSIONS="-Dsonar.exclusions=$SONAR_EXCLUSIONS"
fi

curl --noproxy $NO_PROXY -I --insecure $SONAR_URL/about
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$( echo "$SONAR_URL/api/projects/create?&project=$COMPONENT_ID&name="$COMPONENT_NAME"" | sed 's/ /%20/g' )"
curl --noproxy $NO_PROXY --insecure -X POST -u $SONAR_APIKEY: "$SONAR_URL/api/qualitygates/select?projectKey=$COMPONENT_ID&gateId=$SONAR_GATEID"

if [ "$BUILD_TOOL" == "maven" ]; then
    MAVEN_PROXY_IGNORE=`echo "$NO_PROXY" | sed -e 's/ //g' -e 's/\"\,\"/\|/g' -e 's/\,\"/\|/g' -e 's/\"$//' -e 's/\,/\|/g'`
    export MAVEN_OPTS="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttp.nonProxyHosts='$MAVEN_PROXY_IGNORE' -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT -Dhttps.nonProxyHosts='$MAVEN_PROXY_IGNORE'"
    export SONAR_SCANNER_OPTS="-Xmx1024m"

    DEBUG_OPTS=
    if [ "$DEBUG" == "true" ]; then
        echo "Enabling debug logging..."
        DEBUG_OPTS+="--debug -Dsonar.verbose=true"
    fi

    # Set java environment varaibles as per initialize-dependencies-java.sh
    source ~/.profile
    echo "JAVA_HOME (compile): $JAVA_HOME"
    echo "PATH (compile): $PATH"

    # Compile source
    mvn clean compile -Dversion.name=$VERSION_NAME $DEBUG_OPTS $MAVEN_OPTS -DskipTests=true -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true -Dmaven.wagon.http.ssl.ignore.validity.dates=true

    # Test source
    mvn clean test -Dversion.name=$VERSION_NAME $DEBUG_OPTS $MAVEN_OPTS

    # Set to Java 17 for Sonarqube
    echo "Set to Java 17 for Sonarqube..."
    echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk" >> ~/.profile
    echo "export PATH=/usr/lib/jvm/java-17-openjdk/bin:$PATH" >> ~/.profile

    source ~/.profile
    echo "JAVA_HOME (sonar): $JAVA_HOME"
    echo "PATH (sonar): $PATH"

    # Run Sonarqube
    mvn sonar:sonar -Dversion.name=$VERSION_NAME -Dsonar.login=$SONAR_APIKEY -Dsonar.host.url="$SONAR_URL" -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion=$VERSION_NAME -Dsonar.scm.disabled=true -Dsonar.junit.reportPaths=target/surefire-reports -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true -Dmaven.wagon.http.ssl.ignore.validity.dates=true $SONAR_SCANNER_EXCLUSIONS $DEBUG_OPTS $MAVEN_OPTS
    # mvn sonar:sonar -DskipTests=true -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true -Dmaven.wagon.http.ssl.ignore.validity.dates=true -Dsonar.login=$SONAR_APIKEY -Dsonar.host.url=$SONAR_URL -Dsonar.projectKey=$COMPONENT_ID -Dsonar.projectName="$COMPONENT_NAME" -Dsonar.projectVersion=$VERSION_NAME -Dsonar.verbose=true -Dsonar.scm.disabled=true $SONAR_SCANNER_EXCLUSIONS

elif [ "$BUILD_TOOL" == "gradle" ]; then
    echo "ERROR: Gradle not implemented yet."
    exit 1
else
    echo "ERROR: no build tool specified."
    exit 1
fi
