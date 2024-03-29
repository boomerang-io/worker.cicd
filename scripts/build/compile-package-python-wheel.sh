#!/bin/bash

# ( echo "\n"; echo "%.0s-" {1..30}; echo " Build Artifact "; echo "%.0s-" {1..30}; echo "\n\n" )

BUILD_LANGUAGE_VERSION=$1
VERSION_NAME=$2
ART_URL=$3
ART_REPO_ID=$4
ART_REPO_USER=$5
ART_REPO_PASSWORD=$6

ART_REPO_HOME=~/.pypirc
cat >> $ART_REPO_HOME <<EOL
[distutils]
index-servers = local
[local]
repository: $ART_URL/$ART_REPO_ID
username: $ART_REPO_USER
password: $ART_REPO_PASSWORD
EOL

# TODO Determine if we need to override `version` in setup.py using $VERSION_NAME

if [ "$BUILD_LANGUAGE_VERSION" == "2" ]; then
	echo "Python 2 no longer supported..."
	exit 89
else
	pip3 install setuptools wheel twine
	python3 setup.py sdist bdist_wheel
	pip3 wheel . -w bdist_wheel
	twine upload --repository local bdist_wheel/*
fi
