#!/bin/bash

# Set the exit status $? to the exit code of the last program to exit non-zero (or zero if all exited successfully)
set -o pipefail

export KUBE_HOME="$HOME"/.kube
BIN_HOME=/usr/local/bin
KUBE_CLI="$BIN_HOME"/kubectl

log() {
    local TYPE MSG RED YELLOW GREEN CYAN RS DATE FN
    TYPE="$1"
    MSG="$2"
    RED="\033[0;91m"
    YELLOW="\033[0;93m"
    GREEN="\033[0;92m"
    CYAN="\033[0;96m"
    RS="\033[0m"
    DATE=$(date '+%F %T %Z')
    FN=${FUNCNAME[*]: -2:1}
    case ${TYPE} in
    -e | --[eE][rR][rR][oO][rR])
        printf "[${RED}ERROR${RS}] [${DATE}] [$FN] [$BASH_LINENO] %s\n" "$MSG"
        ;;
    -w | --[wW][aA][rR][nN])
        printf "[${YELLOW}WARN${RS}]  [${DATE}] [$FN] [$BASH_LINENO] %s\n" "$MSG"
        ;;
    -d | --[dD][eE][bB][uU][gG])
        printf "[${CYAN}DEBUG${RS}] [${DATE}] [$FN] [$BASH_LINENO] %s\n" "$MSG"
        ;;
    -i | --[iI][nN][fF][oO])
        printf "[${GREEN}INFO${RS}]  [${DATE}] [$FN] [$BASH_LINENO] %s\n" "$MSG"
        ;;
    *)
        printf "[OTHER] [${DATE}] [$FN] [$BASH_LINENO] '$1' option for function '${FUNCNAME[0]}' is not available\n"
        ;;
    esac
}

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
    if [[ $1 ]] && [[ ${1:0:1} != - ]] && [[ $1 != undefined ]]; then
        echo "$1"
    else
        # If the parameter is empty, print the message to stderr and return 1 (variable will not be changed)
        echo "$2" >&2
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
        [HELM_SET_ARGS]=""
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
        --kube-namespace) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]=$(return_abnormal "$2" "$(log -e "'$1' requires a non-empty option argument.")") || ((RETURN_ABNORMAL_TOTAL++))
            shift
            ;;
        --kube-host) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]=$(return_abnormal "$2" "$(log -e "'$1' requires a non-empty option argument.")") || ((RETURN_ABNORMAL_TOTAL++))
            shift
            ;;
        --kube-version) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[DEPLOY_KUBE_VERSION]=$(return_abnormal "$2" "$(log -w "'$1' optional argument was not provided.")")
            shift
            ;;
        --repo-url) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[HELM_REPO_URL]=$(return_abnormal "$2" "$(log -e "'$1' requires a non-empty option argument.")") || ((RETURN_ABNORMAL_TOTAL++))
            shift
            ;;
        --chart-repo) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[CHART_REPO]=$(return_abnormal "$2" "$(log -w "'$1' optional argument was not provided.")")
            shift
            ;;
        --chart-name) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[CHART_NAME]=$(return_abnormal "$2" "$(log -w "'$1' optional argument was not provided.")")
            shift
            ;;
        --chart-version) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[CHART_VERSION]=$(return_abnormal "$2" "$(log -w "'$1' optional argument was not provided.")")
            shift
            ;;
        --release-name) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[HELM_RELEASE_NAME]=$(return_abnormal "$2" "$(log -w "'$1' optional argument was not provided.")")
            shift
            ;;
        --helm-set-args) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[HELM_SET_ARGS]=$(return_abnormal "$2" "$(log -w "'$1' optional argument was not provided.")")
            shift
            ;;
        --image-key) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[HELM_IMAGE_KEY]=$(return_abnormal "$2" "$(log -w "'$1' optional argument was not provided.")")
            shift
            ;;
        --image-version) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[IMAGE_KEY_VERSION_NAME]=$(return_abnormal "$2" "$(log -w "'$1' optional argument was not provided.")")
            shift
            ;;
        --git-url) # Takes an option argument; ensure it has been specified.
            PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]=$(return_abnormal "$2" "$(log -w "'$1' optional argument was not provided.")")
            shift
            ;;
        --debug) # If set to true it enables debug
            PARAMETERS_ARRAY[DEBUG]=$(return_abnormal "$2" "$(log -w "'$1' optional argument was not provided.")")
            debug_mode
            shift
            ;;
        -* | --*=) # unsupported flags
            log -e "Unsupported flag '$1'" >&2
            exit
            ;;
        *) # preserve positional arguments
            CMD_PARAMS="$CMD_PARAMS $1"
            shift
            ;;
        esac
    done
    if [[ $RETURN_ABNORMAL_TOTAL -gt 0 ]]; then echo && exit; fi
    eval set -- "$CMD_PARAMS"
}

debug_mode() {
    if [[ ${PARAMETERS_ARRAY[DEBUG]} == true ]]; then
        log -d "--kube-host=${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}"
        log -d "--kube-namespace=${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}"
        log -d "--kube-version=${PARAMETERS_ARRAY[DEPLOY_KUBE_VERSION]}"
        log -d "--repo-url=${PARAMETERS_ARRAY[HELM_REPO_URL]}"
        log -d "--chart-repo=${PARAMETERS_ARRAY[CHART_REPO]}"
        log -d "--chart-name=${PARAMETERS_ARRAY[CHART_NAME]}"
        log -d "--chart-version=${PARAMETERS_ARRAY[CHART_VERSION]}"
        log -d "--release-name=${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"
        log -d "--image-key=${PARAMETERS_ARRAY[HELM_IMAGE_KEY]}"
        log -d "--image-version=${PARAMETERS_ARRAY[IMAGE_KEY_VERSION_NAME]}"
        log -d "--git-url=${PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]}"
        # Debug option for helm
        DEBUG_OPTS="--debug"
    fi
}

helm_repo_add_and_update() {
    local HELM_REPO_ADD HELM_REPO_UPDATE
    # Add the helm chart repo. Default to 'boomerang-charts' repo name is not provided
    if [[ -z ${PARAMETERS_ARRAY[CHART_REPO]} ]]; then
        PARAMETERS_ARRAY[CHART_REPO]="default"
        log -w "Helm chart repo name was not provided... Setting it to 'default'"
    fi
    log -i "Adding '${PARAMETERS_ARRAY[CHART_REPO]}' repo with URL '${PARAMETERS_ARRAY[HELM_REPO_URL]}'"
    HELM_REPO_ADD=$(helm repo add "${PARAMETERS_ARRAY[CHART_REPO]}" "${PARAMETERS_ARRAY[HELM_REPO_URL]}" 2>&1)
    if [[ $? -ne 0 ]]; then
        log -e "$HELM_REPO_ADD"
        exit
    else
        log -i "$HELM_REPO_ADD"
    fi
    log -i "Updating helm repo..."
    HELM_REPO_UPDATE=$(helm repo update)
    if [[ $? -ne 0 ]]; then
        log -e "$HELM_REPO_UPDATE"
        exit
    else
        log -i "$HELM_REPO_UPDATE"
    fi
}

parse_helm_values() {
    if [[ ${PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]} ]]; then
        CURL_HEADER_OUTPUT=($(curl -sLO "${PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]}" -w "%{filename_effective} %{http_code} %{url_effective}"))
        # Normalize filename if it comes from a private repo that has token as URL parameter
        HELM_GIT_VALUES_FILE=$(cut -d? -f1 <<<"${CURL_HEADER_OUTPUT[0]}")
        mv ${CURL_HEADER_OUTPUT[0]} $HELM_GIT_VALUES_FILE
        if [[ ${CURL_HEADER_OUTPUT[1]} -ne 200 ]]; then
            log -e "Error ${CURL_HEADER_OUTPUT[1]}: '$HELM_GIT_VALUES_FILE' file could not be retrieved."
            log -e "Referer URL: ${CURL_HEADER_OUTPUT[2]}"
            exit
        fi
        # Add extra validation for the YAML file
        yq eval 'true' $HELM_GIT_VALUES_FILE &>/dev/null
        # Return -f parameter and the final values file name
        HELM_GIT_VALUES_FILE=(-f $HELM_GIT_VALUES_FILE)
    fi
}

# Retrieve the yaml output of a helm release
get_yaml_output_for_helm_release() {
    HELM_YAML_OUTPUT=$(helm list --all --kube-context "${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}" --namespace "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" -o yaml 2>&1)
    if [[ $? -ne 0 ]]; then
        log -e "$HELM_YAML_OUTPUT"
        echo
        exit
    elif [[ $HELM_YAML_OUTPUT == [] ]]; then
        log -e "There are no helm deployments in '${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}' namespace."
        echo
        exit
    fi

    # If both release and chart names were provided, check that the release matches with the chart name
    if [[ ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]} ]] && [[ ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        RELEASE_NAME=$(yq eval '.[] | select (.chart == "*'"${PARAMETERS_ARRAY[CHART_NAME]}"'*") |
            .name | select (. == "*'"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"'*")' - <<<"$HELM_YAML_OUTPUT")
        if [[ $RELEASE_NAME != ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]} ]]; then
            HELM_RELEASE_ARRAY=($(yq eval '.[] | select (.chart == "*'"${PARAMETERS_ARRAY[CHART_NAME]}"'*") | 
                .name as $name | $name' - <<<"$HELM_YAML_OUTPUT"))
            log -e "Release name '${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}' does not match with any release from '${PARAMETERS_ARRAY[CHART_NAME]}' chart."
            log -e "Available release names for '${PARAMETERS_ARRAY[CHART_NAME]}' chart name in '${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}' namespace: ${HELM_RELEASE_ARRAY[*]}"
            echo
            exit
        fi
    # If the release name is present and the chart name is empty, check that release name exists in that namespace
    elif [[ ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]} ]] && [[ -z ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        RELEASE_EXISTS_IN_NS=$(yq eval '.[] | select (.name == "*'"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"'*")' - <<<"$HELM_YAML_OUTPUT")
        if [[ -z $RELEASE_EXISTS_IN_NS ]]; then
            log -e "Release name '${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}' cannot be found in '${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}' namespace."
            echo
            exit
        fi
    fi

    # Get Release Name based on the chart name.
    # If there are multiple releases, show a warning message and stop
    if [[ -z ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]} ]] && [[ ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        log -w "Release name was not provided, auto detecting it..."
        HELM_RELEASE_ARRAY=($(yq eval '.[] | select (.chart == "*'"${PARAMETERS_ARRAY[CHART_NAME]}"'*") | 
            .name as $name | $name' - <<<"$HELM_YAML_OUTPUT"))
        if [[ ${#HELM_RELEASE_ARRAY[@]} -gt 1 ]]; then
            log -e "Multiple releases found: ${HELM_RELEASE_ARRAY[*]}"
            log -e "Auto detection works if there is only one release of the chart in the provided namespace."
            log -e "You must provide the release name in order to deploy the chart."
            echo
            exit
        else
            PARAMETERS_ARRAY[HELM_RELEASE_NAME]="${HELM_RELEASE_ARRAY[*]}"
            log -i "Release name detected as: ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"
        fi
    elif [[ -z ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]} ]] && [[ -z ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        log -w "Release name was not provided, auto detecting it..."
        log -e "Release name cannot be auto detected because chart name is empty."
        log -e "You must provide the chart name in order to auto detect the release name."
        echo
        exit
    fi

    # CHART_NAME is blank. Helm release name is now required to fetch chart name.
    if [[ -z ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        PARAMETERS_ARRAY[CHART_NAME]=$(yq eval '.[] | select (.name == "*'"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"'*") | 
            .chart as $chart | $chart' - <<<"$HELM_YAML_OUTPUT" | cut -d- -f1)
        log -w "Chart name was not provided, auto detecting it..."
        log -i "Chart name detected as: ${PARAMETERS_ARRAY[CHART_NAME]}"
    fi

    # Get Chart Version based on the release name
    if [[ -z ${PARAMETERS_ARRAY[CHART_VERSION]} ]]; then
        PARAMETERS_ARRAY[CHART_VERSION]=$(yq eval '.[] | select (.name == "*'"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"'*") | 
            .chart as $chart | $chart' - <<<"$HELM_YAML_OUTPUT" | cut -d- -f2)
        log -w "Chart version was not provided, auto detecting it..."
        log -i "Chart version detected as: ${PARAMETERS_ARRAY[CHART_VERSION]}"
    fi
}

upgrade_helm_release() {
    get_yaml_output_for_helm_release
    helm_repo_add_and_update

    log -i "Chart Namespace: ${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}"
    log -i "Chart Name: ${PARAMETERS_ARRAY[CHART_NAME]}"
    log -i "Chart Version: ${PARAMETERS_ARRAY[CHART_VERSION]}"
    log -i "Release Name: ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"
    log -i "Application Image Path: ${PARAMETERS_ARRAY[HELM_IMAGE_KEY]}"
    log -i "Application Image Version: ${PARAMETERS_ARRAY[IMAGE_KEY_VERSION_NAME]}"
    log -i "Helm set parameters: ${PARAMETERS_ARRAY[HELM_SET_ARGS]}"

    HELM_CHART_EXITCODE=0
    SLEEP=30
    RETRIES=4
    log -i "Upgrading helm release..."
    log -i "NOTE: Timeout is set at 5 minutes with 3 retries"
    # default timeout for helm commands is 300 seconds so no need to adjust
    INDEX=0
    until [[ $INDEX -ge $RETRIES ]]; do
        let INDEX++
        if [[ $INDEX -eq $RETRIES ]]; then
            log -e "Failed to achieve the helm deployment within allotted time and retry count."
            HELM_CHART_EXITCODE=91
            break
        else
            log -i "Commencing deployment (attempt #$INDEX)..."
            parse_helm_values "${PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]}"
            DEPLOYMENT_OUTPUT=$(helm upgrade --kube-context "${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}" "${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}" \
                --namespace "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" --reuse-values "${HELM_GIT_VALUES_FILE[@]}" $DEBUG_OPTS \
                --set "${PARAMETERS_ARRAY[HELM_IMAGE_KEY]}"="${PARAMETERS_ARRAY[IMAGE_KEY_VERSION_NAME]}" --set "${PARAMETERS_ARRAY[HELM_SET_ARGS]}" \
                --version "${PARAMETERS_ARRAY[CHART_VERSION]}" "${PARAMETERS_ARRAY[CHART_REPO]}"/"${PARAMETERS_ARRAY[CHART_NAME]}" 2>&1 >/dev/null)
            DEPLOYMENT_RESULT=$?
            if [[ ${PARAMETERS_ARRAY[DEBUG]} == true ]] && [[ $DEPLOYMENT_RESULT -eq 0 ]]; then
                log -d "$DEPLOYMENT_OUTPUT"
            fi
            if [[ $DEPLOYMENT_RESULT -ne 0 ]]; then
                if [[ $DEPLOYMENT_OUTPUT =~ "timed out" ]]; then
                    log -w "Time out reached. Retrying..."
                    sleep $SLEEP
                    continue
                else
                    HELM_CHART_EXITCODE=91
                    break
                fi
            fi
            log -i "Deployment success."
            echo
            helm ls -n "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" -f ^"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"$
            echo
            break
        fi
    done
    # Final block to count success of print error for this loop
    if [[ $HELM_CHART_EXITCODE -ne 0 ]]; then
        log -e "$DEPLOYMENT_OUTPUT"
        log -e "Unable to deploy to '${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}'. The last error code received was: $HELM_CHART_EXITCODE. Please speak to a DevOps representative or try again."
        # TODO: update to print out error statement based on code.
    fi
}

# Call all the necessary functions
echo
get_parameters "$@"
upgrade_helm_release "$@"
echo
