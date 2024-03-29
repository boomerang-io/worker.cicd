#!/bin/bash

#( printf '\n'; printf '%.0s-' {1..30}; printf ' Automated Web Testing via Selenium Native'; printf '%.0s-' {1..30}; printf '\n\n' )

COMPONENT_NAME=${1}
VERSION_NAME=${2}
API_KEY=${3}
API_USERNAME=${4}
API_URI=${5}
BROWSER_NAME=${6}
BROWSER_VERSION=${7}
PLATFORM_TYPE=${8}
PLATFORM_VERSION=${9}
WEB_TESTS_FOLDER=${10}
GIT_USER=${11}
GIT_PASSWORD=${12}

# make java environment varaibles set by initialize-dependencies-java.sh effective.
source ~/.profile
echo "JAVA_HOME: $JAVA_HOME"
echo "PATH: $PATH"

touch junits.java

if [ -d "$WEB_TESTS_FOLDER" ]; then
  ls -al $WEB_TESTS_FOLDER/*.java
  for FILE_NAME_PATH in $WEB_TESTS_FOLDER/*.java
  do
    METHOD=`echo "$FILE_NAME_PATH" | cut -d'/' -f2 | cut -d'.' -f1`
    CODE=`cat $FILE_NAME_PATH`

    cat >> junits.java <<EOL
    @Test
    public void test$METHOD() {
      RemoteWebDriver driver = getDriver();

$CODE
    }

EOL
  done
fi

mkdir webtest
cd webtest

git clone --recurse-submodules https://${GIT_USER}:${GIT_PASSWORD}@github.ibm.com/Boomerang-Delivery/boomerang.test.template.selenium.git .
git checkout develop

cat > src/test/resources/application.properties <<EOL
api.key=$API_KEY
api.username=$API_USERNAME
api.uri=$API_URI
browser.name=$BROWSER_NAME
browser.version=$BROWSER_VERSION
platform.name=$PLATFORM_TYPE $PLATFORM_VERSION
build.tag=$COMPONENT_NAME:$VERSION_NAME - $BROWSER_NAME:$BROWSER_VERSION - $PLATFORM_TYPE:$PLATFORM_VERSION
http.proxyHost=$PROXY_HOST
http.proxyPort=$PROXY_PORT
https.proxyHost=$PROXY_HOST
https.proxyPort=$PROXY_PORT
EOL

cat src/test/resources/application.properties

awk '{if (match($0,"------SELENIUM METHODS GO HERE------")) exit; print}' src/test/java/net/boomerangplatform/ApplicationTest.java > temp.java
cat ../junits.java >> temp.java
echo "}" >> temp.java
mv -f temp.java src/test/java/net/boomerangplatform/ApplicationTest.java

cat src/test/java/net/boomerangplatform/ApplicationTest.java

MAVEN_PROXY_IGNORE=`echo "$NO_PROXY" | sed -e 's/ //g' -e 's/\"\,\"/\|/g' -e 's/\,\"/\|/g' -e 's/\"$//' -e 's/\,/\|/g'`
export MAVEN_OPTS="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttp.nonProxyHosts='$MAVEN_PROXY_IGNORE' -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT -Dhttps.nonProxyHosts='$MAVEN_PROXY_IGNORE'"

export USE_PROXY=true

env http.proxyHost=$PROXY_HOST http.proxyPort=$PROXY_PORT https.proxyHost=$PROXY_HOST https.proxyPort=$PROXY_PORT mvn clean test
