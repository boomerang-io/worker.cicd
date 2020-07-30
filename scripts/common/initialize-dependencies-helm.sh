#!/bin/bash

# Supported versions are
#   ICP 2.x
#   ICP 3.1 - different versions of kube and helm
#   ICP 3.2 - different versions of kube, helm, and cert locations
#
# Reference:
#   Forked from: https://github.ibm.com/ICP-DevOps/build-harness/blob/master/modules/helm/Makefile

BUILD_TOOL=$1

BUILD_HARNESS_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
BUILD_HARNESS_ARCH=$(uname -m | sed 's/x86_64/amd64/g')
HELM_PLATFORM=$BUILD_HARNESS_OS
HELM_ARCH=$BUILD_HARNESS_ARCH
if [ "$BUILD_TOOL" == "helm3" ]; then
    HELM_VERSION=v3.2.4
    HELM_URL=https://get.helm.sh/helm-$HELM_VERSION-$HELM_PLATFORM-$HELM_ARCH.tar.gz
else
    HELM_VERSION=v2.12.1
    HELM_URL=https://kubernetes-helm.storage.googleapis.com/helm-$HELM_VERSION-$HELM_PLATFORM-$HELM_ARCH.tar.gz
fi
HELM_HOME=/opt/bin/helm

echo "Installing Helm $HELM_VERSION ($HELM_PLATFORM-$HELM_ARCH) from $HELM_URL"
curl '-#' -fL -o /tmp/helm.tar.gz --retry 5 $HELM_URL
if [ $? -ne 0 ] ; then
    echo
    echo  "   ✗ An error occurred installing Helm. Please see output for details or talk to a support representative." "error"
    echo
    exit 1
fi
tar xzf /tmp/helm.tar.gz -C /tmp
mv /tmp/$HELM_PLATFORM-$HELM_ARCH/helm $HELM_HOME
rm -f /tmp/helm.tar.gz
rm -rf /tmp/$HELM_PLATFORM-$HELM_ARCH

echo "Symbolic link for Helm"
if [ -f /usr/bin/helm ]; then
echo "Link already exists"
else
echo "Creating symbolic link for Helm in /usr/bin"
ln -s $HELM_HOME /usr/bin/helm
fi

if [ "$BUILD_TOOL" == "helm3" ]; then
    echo "Verifying Helm client..."
    helm version
    if [ $? -ne 0 ] ; then
        echo
        echo  "   ✗ An error occurred installing Helm. Please see output for details or talk to a support representative." "error"
        echo
        exit 1
    fi
else
    echo "Verifying Helm client..."
    helm version --client --short
    if [ $? -ne 0 ] ; then
        echo
        echo  "   ✗ An error occurred installing Helm. Please see output for details or talk to a support representative." "error"
        echo
        exit 1
    fi
    echo "Initializing Helm"
    helm init --client-only --skip-refresh
fi