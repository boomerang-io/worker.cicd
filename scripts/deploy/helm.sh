#!/bin/bash

HELM_REPO_URL=$1
CHART_NAME=$2
CHART_RELEASE=$3
HELM_IMAGE_KEY=$4
VERSION_NAME=$5
DEPLOY_KUBE_VERSION=$6
DEPLOY_KUBE_NAMESPACE=$7
DEPLOY_KUBE_HOST=$8

if [ "$DEBUG" == "true" ]; then
    echo "DEBUG - Script input variables..."
    echo "HELM_REPO_URL=$HELM_REPO_URL"
    echo "CHART_NAME=$CHART_NAME"
    echo "CHART_RELEASE=$CHART_RELEASE"
    echo "HELM_IMAGE_KEY=$HELM_IMAGE_KEY"
    echo "VERSION_NAME=$VERSION_NAME"
    echo "DEPLOY_KUBE_VERSION=$DEPLOY_KUBE_VERSION"
    echo "DEPLOY_KUBE_NAMESPACE=$DEPLOY_KUBE_NAMESPACE"
    echo "DEPLOY_KUBE_HOST=$DEDEPLOY_KUBE_HOST"
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
    CHART_NAME=`helm list --kube-context $DEPLOY_KUBE_HOST-context --filter ^$CHART_RELEASE$ -o yaml | yq read - .chart | rev | cut -d '-' -f 2- | rev`
    if [ $? -ne 0 ]; then exit 92; fi
elif [ -z "$CHART_NAME" ] && [ -z "$CHART_RELEASE" ]; then
    exit 92
fi

echo "Chart Namespace: $DEPLOY_KUBE_NAMESPACE"
echo "Chart Name(s): $CHART_NAME"
echo "Chart Image Tag: $HELM_IMAGE_KEY"
echo "Chart Image Version: $VERSION_NAME"

HELM_CHARTS_EXITCODE=0
HELM_CHARTS_SUCCESS_COUNT=0
IFS=',' # comma (,) is set as delimiter
read -ra HELM_CHARTS_ARRAY <<< "$CHART_NAME"
HELM_CHARTS_ARRAY_SIZE=${#HELM_CHARTS_ARRAY[@]}
# We assume all the helm charts will be of the same type, either 2 all 3.
if [[ $HELM_CHARTS_ARRAY_SIZE > 1 ]]; then
    echo "Multiple charts ($HELM_CHARTS_ARRAY_SIZE) found. Enabling 'warning' mode for failures - this will mark activity as successful if one or more charts succeed."
fi
for CHART in "${HELM_CHARTS_ARRAY[@]}"; do
    # Each of these blocks will set an EXITCODE to handle a soft exit if there are multiple charts.
    echo "Current Chart Name: $CHART"
    if [[ -z "$CHART_RELEASE" ]] && [ ! -z "$DEPLOY_KUBE_NAMESPACE" ]; then
        echo "Auto detecting chart release..."
        echo "Note: This only works if there is only one release of the chart in the provided namespace."
        CHART_RELEASE=`helm list --kube-context $DEPLOY_KUBE_HOST-context -n $DEPLOY_KUBE_NAMESPACE -o yaml | yq read - [chart==$CHART*].name`
        if [ $? -ne 0 ]; then echo "No Helm 3 chart release found in namespace: $DEPLOY_KUBE_NAMESPACE" && exit 94; fi
    elif [ -z "$CHART_RELEASE" ] && [ -z "$DEPLOY_KUBE_NAMESPACE" ]; then
        HELM_CHARTS_EXITCODE=93
    fi
    if [ ! -z "$CHART_RELEASE" ] && [ $HELM_CHARTS_EXITCODE -eq 0 ]; then
        echo "Current Chart Release: $CHART_RELEASE"
        CHART_VERSION=`helm list --kube-context $DEPLOY_KUBE_HOST-context --filter ^$CHART_RELEASE$ -o yaml | yq read - .chart | rev | cut -d '-' -f 1 | rev`
        if [ $? -ne 0 ]; then exit 94; fi
    fi
    if [ ! -z "$CHART_RELEASE" ] && [ ! -z "$CHART_VERSION" ] && [ $HELM_CHARTS_EXITCODE -eq 0 ]; then
        echo "Current Chart Version: $CHART_VERSION"
        echo "Upgrading helm release..."
        SLEEP=30
        RETRIES=3
        echo "Note: Timeout is set at 5 minutes with 3 retries"
        # default timeout for helm commands is 300 seconds so no need to adjust
        INDEX=0
        while true; do
            INDEX=$(( INDEX + 1 ))
            if [[ $INDEX -eq $RETRIES ]]; then
                echo "Failed to achieve the helm deployment within allotted time and retry count."
                HELM_CHARTS_EXITCODE=91;
                break
            else
                echo "Commencing deployment (attempt #$INDEX)..."
                OUTPUT=$(helm upgrade --kube-context $DEPLOY_KUBE_HOST-context --reuse-values --set $HELM_IMAGE_KEY=$VERSION_NAME --version $CHART_VERSION $CHART_RELEASE boomerang-charts/$CHART)
                RESULT=$?
                if [ $RESULT -ne 0 ]; then 
                    if [[ $OUTPUT =~ "timed out" ]]; then
                        echo "Time out reached. Retrying..."
                        sleep $SLEEP
                        continue
                    else
                        echo "Error encountered:"
                        echo $OUTPUT
                        HELM_CHARTS_EXITCODE=91;
                        break
                    fi
                fi
                echo "Deployment success."
                break
            fi
        done
    else
        HELM_CHARTS_EXITCODE=94
    fi
    # Final block to count success of print error for this loop
    if [ $HELM_CHARTS_EXITCODE -ne 0 ]; then
        echo "Unable to deploy to $CHART. The last error code received was: $HELM_CHARTS_EXITCODE. Please speak to a DevOps representative or try again."
        # TODO: update to print out error statement based on code.
    else
        ((HELM_CHARTS_SUCCESS_COUNT++))
    fi
    # Reset for next loop as CHART_RELEASE wouldn't have been set to a single release for multiple charts
    CHART_RELEASE=
    HELM_CHARTS_EXITCODE=0
done
IFS=' ' # return to default delimiter

# If at least one deployment is successful, mark whole implementation as successful
if [[ $HELM_CHARTS_SUCCESS_COUNT -eq 0 ]] ; then
    echo "No charts were successful."
    exit 91
elif [[ $HELM_CHARTS_SUCCESS_COUNT -ne $HELM_CHARTS_ARRAY_SIZE ]]; then
    echo
    echo "Warning:"
    echo " - Some charts were unsuccessful. Please review the activity log."
    echo
fi