#!/bin/bash

HELM_REPO_URL=$1
CHART_NAME=$2
CHART_RELEASE=$3
CHART_VERSION=$4
DEPLOY_KUBE_VERSION=$5
DEPLOY_KUBE_NAMESPACE=$6
DEPLOY_KUBE_HOST=$7
GIT_REF=$8

if [ "$DEBUG" == "true" ]; then
    echo "HELM_REPO_URL=$HELM_REPO_URL"
    echo "CHART_NAME=$CHART_NAME"
    echo "CHART_RELEASE=$CHART_RELEASE"
    echo "CHART_VERSION=$CHART_VERSION"
    echo "DEPLOY_KUBE_VERSION=$DEPLOY_KUBE_VERSION"
    echo "DEPLOY_KUBE_NAMESPACE=$DEPLOY_KUBE_NAMESPACE"
    echo "DEPLOY_KUBE_HOST=$DEPLOY_KUBE_HOST"
    echo "GIT_REF=$GIT_REF"
fi

if [[ ! "$GIT_REF" =~ "refs/tags/" ]]; then
    exit 94
fi

export KUBE_HOME=~/.kube
BIN_HOME=/usr/local/bin
KUBE_CLI=$BIN_HOME/kubectl

DEBUG_OPTS=
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    DEBUG_OPTS+='--debug'
else
    # Bug in current version of helm that only checks if DEBUG is present
    # instead of checking for DEBUG=true
    # https://github.com/helm/helm/issues/2401
    unset DEBUG
fi

# Set the exit status $? to the exit code of the last program to exit non-zero (or zero if all exited successfully)
set -o pipefail

helm repo add boomerang-charts $HELM_REPO_URL && helm repo update

# Chart Name is blank. Chart Release is now required to fetch chart name.
if [ -z "$CHART_NAME" ] && [ ! -z "$CHART_RELEASE" ]; then
    echo "Auto detecting chart name..."
    CHART_NAME=`helm list --kube-context $DEPLOY_KUBE_HOST-context --filter ^$CHART_RELEASE$ | grep $CHART_RELEASE | rev | awk '{print $3}' | cut -d '-' -f 2- | rev`
    if [ $? -ne 0 ]; then exit 92; fi
elif [ -z "$CHART_NAME" ] && [ -z "$CHART_RELEASE" ]; then
    exit 92
fi
echo "Chart Name: $CHART_NAME"
echo "Chart Version: $CHART_VERSION"

# if [[ "$CHART_RELEASE" == "undefined" ]] && [ "$DEPLOY_KUBE_NAMESPACE" !=  == "undefined" ]; then
if [[ -z "$CHART_RELEASE" ]] && [ ! -z "$DEPLOY_KUBE_NAMESPACE" ]; then
    echo "Auto detecting chart release..."
    echo "Note: This only works if there is only one release of the chart in the provided namespace."
    CHART_RELEASE=`helm list --kube-context $DEPLOY_KUBE_HOST-context | grep $CHART_NAME | grep $DEPLOY_KUBE_NAMESPACE | awk '{print $1}'`
    if [ $? -ne 0 ]; then exit 94; fi
elif [ -z "$CHART_RELEASE" ] && [ -z "$DEPLOY_KUBE_NAMESPACE" ]; then
    exit 93
fi
echo "Chart Release: $CHART_RELEASE"

echo "Retrieving current chart values..."
helm get values -a --kube-context $DEPLOY_KUBE_HOST-context $CHART_RELEASE > values.yaml
if [ $? -ne 0 ]; then exit 91; fi

echo "Upgrading helm chart..."
SLEEP=30
RETRIES=3
echo "Note: Timeout is set at 5 minutes with 3 retries"
# default timeout for helm commands is 300 seconds so no need to adjust
INDEX=0
while true; do
    INDEX=$(( INDEX + 1 ))
    if [[ $INDEX -eq $RETRIES ]]; then
        echo "Failed to achieve the helm deployment within allotted time and retry count."
        exit 91;
        break
    else
        echo "Commencing deployment (attempt #$INDEX)..."
        OUTPUT=$(helm upgrade --kube-context $DEPLOY_KUBE_HOST-context -f values.yaml --version $CHART_VERSION $CHART_RELEASE boomerang-charts/$CHART_NAME)
        RESULT=$?
        if [ $RESULT -ne 0 ]; then 
            if [[ $OUTPUT =~ "UPGRADE FAILED: timed out" ]]; then
                echo "Time out reached. Retrying..."
                sleep $SLEEP
                continue
            else
                echo "Error encountered:"
                echo $OUTPUT
                exit 91
            fi
        fi
        echo "Helm chart upgrade success!"
        break
    fi
done
