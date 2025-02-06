#!/bin/bash

# Reference:
#   Forked from: https://github.ibm.com/ICP-DevOps/build-harness/blob/master/modules/helm/Makefile

BUILD_TOOL_VERSION=$1

echo " ⋯ Configuring Helm..."
echo

BUILD_HARNESS_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
BUILD_HARNESS_ARCH=$(uname -m | sed 's/x86_64/amd64/g')
HELM_PLATFORM=$BUILD_HARNESS_OS
HELM_ARCH=$BUILD_HARNESS_ARCH

HELM_VERSION=v3.16.2
if [ ! -z "$BUILD_TOOL_VERSION" ]; then
    HELM_VERSION=v$BUILD_TOOL_VERSION
fi
HELM_URL=https://get.helm.sh/helm-$HELM_VERSION-$HELM_PLATFORM-$HELM_ARCH.tar.gz
HELM_BIN=/opt/bin/helm
echo 
echo "   ⋯ Installing Helm $HELM_VERSION ($HELM_PLATFORM-$HELM_ARCH) from $HELM_URL"
echo 
curl '-#' -fL -o /tmp/helm.tar.gz --retry 5 $HELM_URL
if [ $? -ne 0 ] ; then
    echo
    echo  "   ✗ An error occurred installing Helm. Please see output for details or talk to a support representative." "error"
    echo
    exit 1
fi
tar xzf /tmp/helm.tar.gz -C /tmp
mv /tmp/$HELM_PLATFORM-$HELM_ARCH/helm $HELM_BIN
rm -f /tmp/helm.tar.gz
rm -rf /tmp/$HELM_PLATFORM-$HELM_ARCH
echo "   ↣ Helm installed."

echo "   ⋯ Verifying Symbolic link..."
if [ -f /usr/bin/helm ]; then
echo "   ↣ Link already exists"
else
echo "   ↣ Creating symbolic link for Helm in /usr/bin"
ln -s $HELM_BIN /usr/bin/helm
fi

HELM_HOME=/tmp/.helm

echo "   ⋯ Verifying Helm client..."
helm version --short
if [ $? -ne 0 ] ; then
    echo
    echo  "   ✗ An error occurred installing Helm. Please see output for details or talk to a support representative." "error"
    echo
    exit 1
fi