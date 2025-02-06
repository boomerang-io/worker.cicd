#!/bin/bash

HELM_REPO_URL=$1
HELM_CHART_DIR=$2
HELM_CHART_IGNORE=$3
HELM_CHART_VERSION_INCREMENT=$4
HELM_CHART_VERSION_TAG=$5
GIT_REF=$6

echo "GIT_REF=$GIT_REF"
echo "HELM_REPO_URL=$HELM_REPO_URL"
echo "HELM_CHART_DIR=$HELM_CHART_DIR"
echo "HELM_CHART_VERSION_INCREMENT=$HELM_CHART_VERSION_INCREMENT"
echo "HELM_CHART_VERSION_TAG=$HELM_CHART_VERSION_TAG"
IFS=' ' read -r -a helmChartIgnoreArray <<< "$HELM_CHART_IGNORE"
for index in "${!helmChartIgnoreArray[@]}"
do
    echo "HELM_CHART_IGNORE: $index:${helmChartIgnoreArray[index]}"
done

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
    printf "  Packaging Chart: $chartName\n"
    ( printf '\n'; printf '%.0s-' {1..30}; printf " Packaging Chart: $chartName "; printf '%.0s-' {1..30}; printf '\n' )
    printf "  Chart Path: $chart\n"
    chartNameFolder=$(echo $chart | rev | cut -d'/' -f2- | rev)
    printf "  Chart Folder: $chartNameFolder\n"
    if [[ ! "${chartIgnoreList[@]}" =~ "$chartName" ]] && [[ ! "$chartNameFolder" =~ "${chartIgnoreList[@]}" ]]; then
        if [[ -z "$chartFolder" ]] || [[ "$chartNameFolder" =~ "$chartFolder" ]]; then
            chartVersion=`helm show chart $chartNameFolder | sed -nr 's@(^version: )(.+)@\2@p'`
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
            DEPENDENCY_YAML_FILE='Chart.yaml'
            DEPENDENCY_YAML_PATH="$chartNameFolder/$DEPENDENCY_YAML_FILE"
            printf "  Checking for additional dependencies in $DEPENDENCY_YAML_PATH...\n"
            if [ -f $DEPENDENCY_YAML_PATH ]; then
                # Loop through and ensure all custom dependencies are added
                echo $(yq eval '.dependencies[].repository' $DEPENDENCY_YAML_PATH)
    #             IFS='
    # ' #set as newline
                DEP_ARRAY_STRING=`echo $(yq eval '.dependencies[].repository' $DEPENDENCY_YAML_PATH) | tr '\n' ' '`
                echo "Dependencies found in string: $DEP_ARRAY_STRING"
                read -ra DEP_ARRAY <<< $DEP_ARRAY_STRING
                echo "Dependencies found array: ${DEP_ARRAY[@]}"
                for DEP in "${DEP_ARRAY[@]}"; do
                    if [[ $DEP =~ ^http ]]; then
                        echo "Adding dependency $DEP..."
                        read -ra DEP_NAME <<<$(yq eval '.dependencies[] | select (.repository == "'"$DEP"'") | .name as $name | $name' "$DEPENDENCY_YAML_PATH")
                        helm repo add $DEP_NAME $DEP
                    else
                        echo "Skipping '$DEP' as not a URL"
                    fi
                done
                # IFS=$' '
            else
                printf "  Skipping as no dependencies found in $DEPENDENCY_YAML_FILE.\n"
            fi
            helm dependency update $chartNameFolder/ && \
            helm package --version $chartVersion -d $chartStableDir/ $chartNameFolder/
            RESULT=$?
            if [ $RESULT -ne 0 ] ; then
                exit 89
            fi
        else
            printf "Skipping chart based on directory path...\n"
        fi
    else
        printf "Skipping chart based on ignore list...\n"
    fi
done