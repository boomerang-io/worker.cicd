#!/bin/bash

# Set the exit status $? to the exit code of the last program to exit non-zero (or zero if all exited successfully)
set -o pipefail

export KUBE_HOME="$HOME"/.kube
BIN_HOME=/usr/local/bin
KUBE_CLI="$BIN_HOME"/kubectl

# Help synopsis
show_help() {
    cat <<EOF
Usage: ${0##*/} - TODO: Add help synopsis

EOF
}

return_abnormal() {
    # If one or more rquired command line parameters are epmty add it to the total
    RETURN_ABNORMAL_TOTAL=0
    # Get the value of the parameter and echo it into the variable
    if [[ $1 ]] && [[ ${1:0:1} != - ]]; then
        echo "$1"
    else
        # If the parameter is empty, print the message to stderr and return 1 (variable will not be changed)
        printf '%s\n' "$2" >&2
        return 1
    fi
}

get_parameters() {
    # If no parameters are provided, show the help synopsis and exit
    if [[ $# -eq 0 ]]; then
        show_help
        exit
    fi
    declare -gA PARAMETERS_ARRAY=(
        [DEBUG]=""
        [HELM_REPO_URL]=""
        [CHART_REPO]=""
        [CHART_NAME]=""
        [CHART_VERSION]=""
        [HELM_RELEASE_NAME]=""
        [HELM_IMAGE_KEY]=""
        [IMAGE_KEY_VERSION_NAME]=""
        [DEPLOY_KUBE_VERSION]=""
        [DEPLOY_KUBE_NAMESPACE]=""
        [DEPLOY_KUBE_HOST]=""
        [HELM_VALUES_RAW_GIT_URL]=""
    )
    # Loop over the provided parameters and add them to the list
    CMD_PARAMS=""
    while (("$#")); do
        case "$1" in
        --help)
            show_help # Display a help synopsis.
            exit
            ;;
        --repo-url) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[HELM_REPO_URL]=$(return_abnormal "$2" 'ERROR: "--repo-url" requires a non-empty option argument.') || ((RETURN_ABNORMAL_TOTAL++))
            shift
            ;;
        --chart-repo) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[CHART_REPO]=$(return_abnormal "$2" 'WARN: "--chart-repo" optional argument was not provided.')
            shift
            ;;
        --chart-name) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[CHART_NAME]=$(return_abnormal "$2" 'WARN: "--chart-name" optional argument was not provided.')
            shift
            ;;
        --chart-version) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[CHART_VERSION]=$(return_abnormal "$2" 'WARN: "--chart-version" optional argument was not provided.')
            shift
            ;;
        --release-name) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[HELM_RELEASE_NAME]=$(return_abnormal "$2" 'ERROR: "--release-name" requires a non-empty option argument.') || ((RETURN_ABNORMAL_TOTAL++))
            shift
            ;;
        --image-key) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[HELM_IMAGE_KEY]=$(return_abnormal "$2" 'WARN: "--image-key" optional argument was not provided.')
            shift
            ;;
        --image-version) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[IMAGE_KEY_VERSION_NAME]=$(return_abnormal "$2" 'WARN: "--image-version" optional argument was not provided.')
            shift
            ;;
        --kube-version) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[DEPLOY_KUBE_VERSION]=$(return_abnormal "$2" 'ERROR: "--kube-version" requires a non-empty option argument.') || ((RETURN_ABNORMAL_TOTAL++))
            shift
            ;;
        --kube-namespace) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]=$(return_abnormal "$2" 'ERROR: "--kube-namespace" requires a non-empty option argument.') || ((RETURN_ABNORMAL_TOTAL++))
            shift
            ;;
        --kube-host) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]=$(return_abnormal "$2" 'ERROR: "--kube-host" requires a non-empty option argument.') || ((RETURN_ABNORMAL_TOTAL++))
            shift
            ;;
        --git-url) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]=$(return_abnormal "$2" 'WARN: "--git-url" optional argument was not provided.')
            shift
            ;;
        --debug) # If set to true it enables debug
            PARAMETERS_ARRAY[DEBUG]=$(return_abnormal "$2" 'WARN: "--debug" optional argument was not provided.')
            debug_mode
            shift
            ;;
        -* | --*=) # unsupported flags
            echo "Error: Unsupported flag '$1'" >&2
            exit 1
            ;;
        *) # preserve positional arguments
            CMD_PARAMS="$CMD_PARAMS $1"
            shift
            ;;
        esac
    done
    if [[ RETURN_ABNORMAL_TOTAL -gt 0 ]]; then exit; fi
    eval set -- "$CMD_PARAMS"
}

debug_mode() {
    if [[ ${PARAMETERS_ARRAY[DEBUG]} == true ]]; then
        echo -e "\nDEBUG MODE ENABLED - Script input variables..."
        echo "--repo-url=${PARAMETERS_ARRAY[HELM_REPO_URL]}"
        echo "--chart-repo=${PARAMETERS_ARRAY[CHART_REPO]}"
        echo "--chart-name=${PARAMETERS_ARRAY[CHART_NAME]}"
        echo "--chart-version=${PARAMETERS_ARRAY[CHART_VERSION]}"
        echo "--release-name=${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"
        echo "--image-key=${PARAMETERS_ARRAY[HELM_IMAGE_KEY]}"
        echo "--image-version=${PARAMETERS_ARRAY[IMAGE_KEY_VERSION_NAME]}"
        echo "--kube-version=${PARAMETERS_ARRAY[DEPLOY_KUBE_VERSION]}"
        echo "--kube-namespace=${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}"
        echo "--kube-host=${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}"
        echo "--git-url=${PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]}"
        echo
        # Debug option for helm
        DEBUG_OPTS="--debug"
    fi
}

helm_repo_add_and_update() {
    # Add the helm chart repo. Default to 'boomerang-charts' repo name is not provided
    if [[ -z ${PARAMETERS_ARRAY[CHART_REPO]} ]]; then
        PARAMETERS_ARRAY[CHART_REPO]="boomerang-charts"
        echo "Helm chart repo name was not provided... Setting it to 'boomerang-charts'"
    fi
    helm repo add "${PARAMETERS_ARRAY[CHART_REPO]}" "${PARAMETERS_ARRAY[HELM_REPO_URL]}"
    helm repo update
}

parse_helm_values() {
    if [[ ${PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]} ]]; then
        CURL_HEADER_OUTPUT=($(curl -sLO "${PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]}" -w "%{filename_effective} %{http_code} %{url_effective}"))
        # Normalize filename if it comes from a private repo that has token as URL parameter
        HELM_GIT_VALUES_FILE=$(cut -d? -f1 <<<"${CURL_HEADER_OUTPUT[0]}")
        if [[ ${CURL_HEADER_OUTPUT[1]} -ne 200 ]]; then
            echo "Error ${CURL_HEADER_OUTPUT[1]}:'$HELM_GIT_VALUES_FILE' file could not be retrieved."
            echo "Referer URL: ${CURL_HEADER_OUTPUT[2]}"
            exit
        fi
        mv ${CURL_HEADER_OUTPUT[0]} $HELM_GIT_VALUES_FILE
        # Add extra validation for the YAML file
        yq eval 'true' $HELM_GIT_VALUES_FILE &>/dev/null
        # Return -f parameter and the final values file name
        HELM_GIT_VALUES_FILE=(-f $HELM_GIT_VALUES_FILE)
    fi
}

# Retrieve the yaml output of a helm release
get_yaml_output_for_helm_release() {
    HELM_YAML_OUTPUT=$(helm list --kube-context "${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}" --namespace "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" \
        --filter ^"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"$ -o yaml 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "$HELM_YAML_OUTPUT"
        exit 1
    elif [[ $HELM_YAML_OUTPUT == [] ]]; then
        echo "Helm deployment could not be found using namespace '${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}' and release name '${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}'"
        exit 1
    fi
}

upgrade_helm_release() {
    get_yaml_output_for_helm_release
    # CHART_NAME is blank. Helm release name is now required to fetch chart name.
    if [[ -z ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        PARAMETERS_ARRAY[CHART_NAME]=$(yq eval '.[].chart' - <<<"$HELM_YAML_OUTPUT" | cut -d- -f1)
        echo -n "Chart name was not provided, auto detecting it..."
        echo " Chart name detected as: ${PARAMETERS_ARRAY[CHART_NAME]}"
    fi
    # Get Chart Version based on the release name
    if [[ -z ${PARAMETERS_ARRAY[CHART_VERSION]} ]]; then
        PARAMETERS_ARRAY[CHART_VERSION]=$(yq eval '.[].chart' - <<<"$HELM_YAML_OUTPUT" | cut -d- -f2)
        echo -n "Chart version was not provided, auto detecting it..."
        echo " Chart version detected as: ${PARAMETERS_ARRAY[CHART_VERSION]}"
    fi

    helm_repo_add_and_update

    echo -e "\n== Deployment parameters"
    echo "Chart Namespace: ${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}"
    echo "Chart Name: ${PARAMETERS_ARRAY[CHART_NAME]}"
    echo "Chart Version: ${PARAMETERS_ARRAY[CHART_VERSION]}"
    echo "Release Name: ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"
    echo "Application Image Path: ${PARAMETERS_ARRAY[HELM_IMAGE_KEY]}"
    echo "Application Image Version: ${PARAMETERS_ARRAY[IMAGE_KEY_VERSION_NAME]}"
    echo -e "==\n"

    HELM_CHART_EXITCODE=0
    echo "Upgrading helm release..."
    SLEEP=30
    RETRIES=3
    echo "Note: Timeout is set at 5 minutes with 3 retries"
    # default timeout for helm commands is 300 seconds so no need to adjust
    INDEX=0
    while true; do
        ((INDEX++))
        if [[ $INDEX -eq $RETRIES ]]; then
            echo "Failed to achieve the helm deployment within allotted time and retry count."
            HELM_CHART_EXITCODE=91
            break
        else
            echo "Commencing deployment (attempt #$INDEX)..."
            parse_helm_values "${PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]}"
            DEPLOYMENT_OUTPUT=$(helm upgrade --kube-context "${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}" "${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}" \
                --namespace "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" --reuse-values \
                --set "${PARAMETERS_ARRAY[HELM_IMAGE_KEY]}"="${PARAMETERS_ARRAY[IMAGE_KEY_VERSION_NAME]}" \
                --version "${PARAMETERS_ARRAY[CHART_VERSION]}" "${PARAMETERS_ARRAY[CHART_REPO]}"/"${PARAMETERS_ARRAY[CHART_NAME]}" \
                "${HELM_GIT_VALUES_FILE[@]}" $DEBUG_OPTS)
            DEPLOYMENT_RESULT=$?
            if [[ $DEPLOYMENT_RESULT -ne 0 ]]; then
                if [[ $DEPLOYMENT_OUTPUT =~ "timed out" ]]; then
                    echo "Time out reached. Retrying..."
                    sleep $SLEEP
                    continue
                else
                    echo "Error encountered:"
                    echo "$DEPLOYMENT_OUTPUT"
                    HELM_CHART_EXITCODE=91
                    break
                fi
            fi
            echo "Deployment success."
            echo
            helm ls -n "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" -f ^"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"$
            echo
            break
        fi
    done
    # Final block to count success of print error for this loop
    if [[ $HELM_CHART_EXITCODE -ne 0 ]]; then
        echo "Unable to deploy to '${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}'. The last error code received was: $HELM_CHART_EXITCODE. Please speak to a DevOps representative or try again."
        # TODO: update to print out error statement based on code.
    fi
}

# Call all the necessary functions
get_parameters "$@"
upgrade_helm_release "$@"
