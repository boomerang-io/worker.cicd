#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Initialize Python Static Test Dependencies '; printf '%.0s-' {1..30}; printf '\n\n' )

BUILD_LANGUAGE_VERSION=$1
ART_REGISTRY_HOST=$2
ART_REPO_ID=$3
ART_REPO_USER=$4
ART_REPO_PASSWORD=$5

if [ "$DEBUG" == "true" ]; then
  echo "DEBUG - Script input variables..."
  echo "BUILD_LANGUAGE_VERSION=$BUILD_LANGUAGE_VERSION"
  echo "ART_REGISTRY_HOST=$ART_REGISTRY_HOST"
  echo "ART_REPO_ID=$ART_REPO_ID"
  echo "ART_REPO_USER=$ART_REPO_USER"
  echo "ART_REPO_PASSWORD=*****"
fi

# Create Artifactory references for library download
PIP_CONF=~/.pip.conf
cat >> $PIP_CONF <<EOL
[global]
extra-index-url=https://$ART_REPO_USER:$ART_REPO_PASSWORD@$ART_REGISTRY_HOST/artifactory/api/pypi/$ART_REPO_ID/simple
[install]
extra-index-url=https://$ART_REPO_USER:$ART_REPO_PASSWORD@$ART_REGISTRY_HOST/artifactory/api/pypi/$ART_REPO_ID/simple
EOL

# Export pip config home
export PIP_CONFIG_FILE=$PIP_CONF

if [ "$BUILD_LANGUAGE_VERSION" == "2" ]; then
	echo "Python 2 no longer supported ..."
	exit 89
elif [ "$BUILD_LANGUAGE_VERSION" == "3" ]; then
	python3 -m pip install --upgrade setuptools
	python3 -m pip install --upgrade wheel
	python3 -m pip install --upgrade pytest
	python3 -m pip install --upgrade pytest-cov
	python3 -m pip install --upgrade pylint
	python3 -m pip install --upgrade nose
	python3 -m pip install --upgrade coverage
	python3 -m pip install --upgrade nosexcover

	RESULT=$?
	if [ $RESULT -ne 0 ] ; then
		exit 89
	fi
	
else
	echo "Python version not supported ..."
	exit 99
fi
