#!/bin/bash

BUILD_TOOL=$1
HELM_REPO_URL=$2
HELM_CHART_DIR=$3
HELM_CHART_IGNORE=$4

# NOTE:
#  THe following variables are shared with helm.sh for deploy step
HELM_RESOURCE_PATH=/tmp/.helm
# END

if [ "$BUILD_TOOL" == "helm3" ]; then
    helm repo add boomerang-charts $HELM_REPO_URL
else
    helm repo add boomerang-charts $HELM_REPO_URL --home $HELM_RESOURCE_PATH
fi
RESULT=$?
if [ $RESULT -ne 0 ] ; then
    exit 89
fi

# only lint charts which have a `Chart.yaml` and not in ignorelist
chartFolder="$HELM_CHART_DIR"
chartIgnoreList=($HELM_CHART_IGNORE)
chartList=`find . -type f -name 'Chart.yaml'`

for chart in $chartList
do
    #use sed -E instead of -r when testing on Mac
    #chartName=`echo "$chart" | sed 's@\/Chart.yaml@@g' | sed -r "s@\.(\/)?$chartFolder(\/)?@@g"`
    chartName=`echo "$chart" | sed -r "s@\.\/(.*\/)?([^\/]+)\/Chart.yaml@\2@g"`
    chartPath=`echo "$chart" | sed -r "s@(\.\/.*)\/Chart.yaml@\1@g"`
    printf "  Chart Path: $chart\n"
    helm lint $chartPath
    RESULT=$?
    if [ $RESULT -ne 0 ] ; then
        exit 89
    fi
done
