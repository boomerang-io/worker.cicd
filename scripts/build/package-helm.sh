#!/bin/bash

BUILD_TOOL=$1
VERSION_NAME=$2
HELM_REPO_URL=$3
HELM_CHART_DIR=$4
HELM_CHART_IGNORE=$5
HELM_CHART_VERSION_INCREMENT=$6
HELM_CHART_VERSION_TAG=$7
GIT_REF=$8

if [ "$DEBUG" == "true" ]; then
    echo "BUILD_TOOL=$BUILD_TOOL"
    echo "VERSION_NAME=$VERSION_NAME"
    echo "HELM_REPO_URL=$HELM_REPO_URL"
    echo "HELM_CHART_DIR=$HELM_CHART_DIR"
    echo "HELM_CHART_IGNORE=$HELM_CHART_IGNORE"
    echo "HELM_CHART_VERSION_INCREMENT=$HELM_CHART_VERSION_INCREMENT"
    echo "HELM_CHART_VERSION_TAG=$HELM_CHART_VERSION_TAG"
    echo "GIT_REF=$GIT_REF"
fi

# Bug fix for custom certs and re initializing helm home
if [ "$BUILD_TOOL" != "helm3" ]; then
    export HELM_HOME=/tmp/.helm
    # export HELM_HOME=$(helm home)
    echo "   ↣ Helm home set as: $HELM_HOME"
fi

helm repo add boomerang-charts $HELM_REPO_URL
RESULT=$?
if [ $RESULT -ne 0 ] ; then
    exit 89
fi

# only package charts which have a `Chart.yaml` and not in ignorelist
chartFolder=
if [ "$HELM_CHART_DIR" != "undefined" ]; then
    chartFolder=$HELM_CHART_DIR
fi
echo "Chart Folder: $chartFolder"
chartIgnoreList=($HELM_CHART_IGNORE)
chartList=`find . -type f -name 'Chart.yaml'`
chartStableDir=/data/charts/stable
mkdir -p $chartStableDir
if [ "$DEBUG" == "true" ]; then
    echo "Checking /data/charts folder..."
    ls -ltr /data/charts
fi

for chart in $chartList
do
    #use sed -E instead of -r when testing on Mac
    chartName=`echo "$chart" | sed -r "s@\.\/(.*\/)?([^\/]+)\/Chart.yaml@\2@g"`
    ( printf '\n'; printf '%.0s-' {1..30}; printf " Packaging Chart: $chartName "; printf '%.0s-' {1..30}; printf '\n' )
    printf "  Chart Path: $chart\n"
    if [[ ! " ${chartIgnoreList[@]} " =~ " $chartName " ]] && [[ "$chart" =~ ^\.(\/)?$chartFolder(\/)?$chartName\/.*$ ]]; then
        if [ "$BUILD_TOOL" == "helm3" ]; then
            chartVersion=`helm show chart ./$chartFolder/$chartName | sed -nr 's@(^version: )(.+)@\2@p'`
        else
            chartVersion=`helm inspect chart ./$chartFolder/$chartName | grep version | sed 's@version: @@g'`
        fi
        printf "  Existing Chart Version: $chartVersion\n"
        if [[ "$HELM_CHART_VERSION_INCREMENT" == "true" ]]; then
            printf "  Auto Incrementing Chart Version...\n"
            newMajorMinor=`echo $chartVersion | sed -r 's@^([0-9]+\.[0-9]+\.).*@\1@g'`
            newIteration=`echo $chartVersion |  cut -d . -f3 | sed -r 's@^([0-9\.]+)([\-]?.*)$@\1@g'`
            postIteration=`echo $chartVersion |  cut -d . -f3 | sed -r 's@^([0-9\.]+)([\-]?.*)$@\2@g'`
            chartVersion=$newMajorMinor$((newIteration+1))$postIteration
        fi
        if [[ "$HELM_CHART_VERSION_TAG" == "true" ]] && [[ "$GIT_REF" =~ "refs/tags/" ]]; then
            printf "  Seting Chart Version to Tag...\n"
            chartVersion=`echo $GIT_REF | cut -d / -f3`
        fi
        printf "  Chart Version: $chartVersion\n"
        if [ "$BUILD_TOOL" == "helm3" ]; then
            DEPENDENCY_YAML_FILE='Chart.yaml'
        else
            DEPENDENCY_YAML_FILE='requirements.yaml'
        fi
        if [ -z "$chartFolder" ]; then
            DEPENDENCY_YAML_PATH="$chartName/$DEPENDENCY_YAML_FILE"
        else
            DEPENDENCY_YAML_PATH="$chartFolder/$chartName/$DEPENDENCY_YAML_FILE"
        fi
        printf "  Checking for additional dependencies in $DEPENDENCY_YAML_PATH...\n"
        if [ -f $DEPENDENCY_YAML_PATH ]; then
            # Loop through and ensure all custom dependencies are added
            echo $(yq read $DEPENDENCY_YAML_PATH dependencies[*].repository)
#             IFS='
# ' #set as newline
            DEP_ARRAY_STRING=`echo $(yq read $DEPENDENCY_YAML_PATH dependencies[*].repository) | tr '\n' ' '`
            echo "Dependencies found in string: $DEP_ARRAY_STRING"
            read -ra DEP_ARRAY <<< $DEP_ARRAY_STRING
            echo "Dependencies found array: ${DEP_ARRAY[@]}"
            for DEP in "${DEP_ARRAY[@]}"; do
                if [[ $DEP =~ ^http ]]; then
                    echo "Adding dependency $DEP..."
                    read -ra DEP_NAME <<< $(yq read $DEPENDENCY_YAML_PATH dependencies[repository==$DEP].name)
                    helm repo add $DEP_NAME $DEP
                else
                    echo "Skipping '$DEP' as not a URL"
                fi
            done
            # IFS=$' '
        else
            printf "  Skipping as no dependencies found in $DEPENDENCY_YAML_FILE.\n"
        fi
        helm dependency update ./$chartFolder/$chartName/ && \
        helm package --version $chartVersion -d $chartStableDir/ ./$chartFolder/$chartName/
        RESULT=$?
        if [ $RESULT -ne 0 ] ; then
            exit 89
        fi
    else
        printf "Skipping chart based on ignore list or directory path...\n"
    fi
done