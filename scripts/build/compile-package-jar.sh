#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Build Artifact '; printf '%.0s-' {1..30}; printf '\n\n' )

# The only difference between this and standard compile is the mvn versions:set

BUILD_LANGUAGE_VERSION=$1
BUILD_TOOL=$2
BUILD_TOOL_VERSION=$3
VERSION_NAME=$4
ART_URL=$5
ART_REPO_ID=$6
ART_REPO_USER=$7
ART_REPO_PASSWORD=$8
ART_REPO_HOME=~/.m2/repository
if [ -d "/cache" ]; then
    echo "Setting cache..."
    mkdir -p /workspaces/cache/repository
    ls -ltr /workspaces/cache
    ART_REPO_HOME=/workspaces/cache/repository
fi

if [ "$BUILD_LANGUAGE_VERSION" == "17" ]; then
    echo "Language version specified. Installing Java 17..."
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
    export PATH=$JAVA_HOME/bin:$PATH
elif [ "$BUILD_LANGUAGE_VERSION" == "11" ]; then
    echo "Language version specified. Installing Java 11..."
    # apk --no-cache add openjdk11 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community
    export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
    export PATH=$JAVA_HOME/bin:$PATH
elif [ "$BUILD_LANGUAGE_VERSION" == "12" ]; then
    echo "Language version specified. Unfortunately we do not yet support Java 12. Reverting to Java 11."
    # apk --no-cache add openjdk11 --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community
    export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
    export PATH=$JAVA_HOME/bin:$PATH
else
    echo "No language version specified. Defaulting to Java 8..."
    export JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk
    export PATH=$JAVA_HOME/bin:$PATH
    # apk add openjdk8
fi
ls -ltr /usr/lib/jvm
echo $JAVA_HOME
java -version

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
  export PATH=$PATH:/opt/gradle/gradle-$BUILD_TOOL_VERSION/bin
  mkdir -p ~/.gradle
  cat >> ~/.gradle/gradle.properties <<EOL
artifactoryUser=$ART_REPO_USER
artifactoryPassword=$ART_REPO_PASSWORD
artifactoryContextUrl=$ART_URL
artifactoryRepoKey=$ART_REPO_ID
componentVersion=$VERSION_NAME
EOL
  cat ~/.gradle/gradle.properties
  if [ "$HTTP_PROXY" != "" ]; then
      # Swap , for |
      GRADLE_PROXY_IGNORE=`echo "$NO_PROXY" | sed -e 's/ //g' -e 's/\"\,\"/\|/g' -e 's/\,\"/\|/g' -e 's/\"$//' -e 's/\,/\|/g'`
      export GRADLE_OPTS="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttp.nonProxyHosts='$GRADLE_PROXY_IGNORE' -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT -Dhttps.nonProxyHosts='$GRADLE_PROXY_IGNORE'"
  fi
  echo "GRADLE_OPTS=$GRADLE_OPTS"
  gradle clean artifactoryPublish
  RESULT=$?
  if [ $RESULT -ne 0 ] ; then
      exit 89
  fi
else
    echo "ERROR: no build tool specified."
    exit 1
fi
