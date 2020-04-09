#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

# The only difference between this and standard compile is the mvn versions:set

BUILD_TOOL=$1
BUILD_TOOL_VERSION=$2
VERSION_NAME=$3
ART_URL=$4
ART_REPO_ID=$5
ART_REPO_USER=$6
ART_REPO_PASSWORD=$7
ART_REPO_HOME=~/.m2/repository
if [ -d "/cache" ]; then
    echo "Setting cache..."
    mkdir -p /cache/repository
    ls -ltr /cache
    ART_REPO_HOME=/cache/repository
fi

if [ "$BUILD_TOOL" == "maven" ]; then
    mkdir -p ~/.m2
    cat >> ~/.m2/settings.xml <<EOL
<settings>
 <servers>
   <server>
     <id>$ART_REPO_ID</id>
     <username>$ART_REPO_USER</username>
     <password>$ART_REPO_PASSWORD</password>
   </server>
 </servers>
 <localRepository>$ART_REPO_HOME</localRepository>
</settings>
EOL
    if [ "$HTTP_PROXY" != "" ]; then
        # Swap , for |
        MAVEN_PROXY_IGNORE=`echo "$NO_PROXY" | sed -e 's/ //g' -e 's/\"\,\"/\|/g' -e 's/\,\"/\|/g' -e 's/\"$//' -e 's/\,/\|/g'`
        export MAVEN_OPTS="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttp.nonProxyHosts='$MAVEN_PROXY_IGNORE' -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT -Dhttps.nonProxyHosts='$MAVEN_PROXY_IGNORE'"
    fi
    echo "MAVEN_OPTS=$MAVEN_OPTS"
    mvn versions:set versions:commit -DnewVersion=$VERSION_NAME
    mvn clean package deploy --batch-mode -DaltDeploymentRepository=$ART_REPO_ID::default::$ART_URL/$ART_REPO_ID -DrepositoryId=$ART_REPO_ID -DskipTests=true
    RESULT=$?
    if [ $RESULT -ne 0 ] ; then
        exit 89
    fi
elif [ "$BUILD_TOOL" == "gradle" ]; then
    echo "Gradle has not yet been implemented for this mode. Please speak to your DevOps representative."
    exit 1
else
    echo "ERROR: no build tool specified."
    exit 1
fi