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
    # RED="\033[0;91m"
    # YELLOW="\033[0;93m"
    # GREEN="\033[0;92m"
    # CYAN="\033[0;96m"
    # RS="\033[0m"
    DATE=$(date '+%F %T %Z')
    FN=${FUNCNAME[*]: -2:1}
    case ${TYPE} in
    -e | --[eE][rR][rR][oO][rR])
        printf "[ERROR] [${DATE}] [$FN] [$BASH_LINENO] %s\n" "$MSG"
        ;;
    -w | --[wW][aA][rR][nN])
        printf "[WARN]  [${DATE}] [$FN] [$BASH_LINENO] %s\n" "$MSG"
        ;;
    -d | --[dD][eE][bB][uU][gG])
        printf "[DEBUG] [${DATE}] [$FN] [$BASH_LINENO] %s\n" "$MSG"
        ;;
    -i | --[iI][nN][fF][oO])
        printf "[INFO]  [${DATE}] [$FN] [$BASH_LINENO] %s\n" "$MSG"
        ;;
    *)
        printf "[OTHER] [${DATE}] [$FN] [$BASH_LINENO] '$1' option for function '${FUNCNAME[0]}' is not available\n"
        ;;
    esac
}

# Help synopsis
show_help() {
    cat <<EOF
Usage: ${0##*/} [arguments]
    --help                          Show script usage

Required arguments:
    --chart-repo-url                Helm chart repository URL
    --kube-host                     Kubernetes Host (will be used as '--kube-context')
    --kube-namespace                The namespace where Helm can find the release

Optional arguments:
    --chart-name                    Helm chart name
    --chart-repo-name               Helm chart repo name
    --chart-version                 Helm chart version
    --debug                         true | false - whether to enable debug mode or not
    --git-values-custom-dir         Custom directory for the helm values YAML file from Git
    --git-values-file               Helm values YAML file from Git that will overwrite the default values (will be overridden by '--set' if the value paths are the same)
    --helm-set-args                 Helm '--set' arguments (highest order of precedence)
    --kube-version                  Kubernetes / kubectl app version
    --release-name                  Helm release name
    --rollback-release              true | false - whether to rollback the release to the latest stable release on fail
    --working-dir                   Current working directory
EOF
}

return_param_status() {
    if [[ $2 ]] && [[ ${2:0:1} != - ]] && [[ $2 != undefined ]]; then
        RETURN_PARAM_OUTPUT="$2"
        RETURN_PARAM_STATUS=0
    else
        RETURN_PARAM_STATUS=1
        [[ $1 == optional ]] && log -w "'$3' optional argument was not provided."
        [[ $1 == required ]] && log -e "'$3' requires a non-empty option argument." >&2 && ((REQUIRED_EMPTY_PARAM_TOTAL++))
    fi
    REQUIRED_EMPTY_PARAM_TOTAL=${REQUIRED_EMPTY_PARAM_TOTAL:-0}
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
        [DEPLOY_KUBE_VERSION]=""
        [DEPLOY_KUBE_NAMESPACE]=""
        [DEPLOY_KUBE_HOST]=""
        [HELM_VALUES_GIT_FILE]=""
        [HELM_VALUES_GIT_CUSTOM_DIR]=""
        [ROLLBACK_FAILED_RELEASE]=""
        [WORKING_DIR]=""
    )
    # Loop over the provided parameters and add them to the list
    CMD_PARAMS=""
    while (("$#")); do
        case "$1" in
        --help)
            show_help # Display a help synopsis.
            exit
            ;;
        --kube-namespace)
            return_param_status "required" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --kube-host)
            return_param_status "required" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --kube-version)
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[DEPLOY_KUBE_VERSION]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --chart-repo-url)
            return_param_status "required" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[HELM_REPO_URL]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --chart-repo-name)
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[CHART_REPO]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --chart-name)
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[CHART_NAME]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --chart-version)
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[CHART_VERSION]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --release-name)
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[HELM_RELEASE_NAME]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --helm-set-args)
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[HELM_SET_ARGS]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --git-values-file)
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[HELM_VALUES_GIT_FILE]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --git-values-custom-dir)
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[HELM_VALUES_GIT_CUSTOM_DIR]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --rollback-release)
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[ROLLBACK_FAILED_RELEASE]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --working-dir)
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[WORKING_DIR]="$RETURN_PARAM_OUTPUT"
            shift
            ;;
        --debug) # If set to true it enables debug
            return_param_status "optional" "$2" "$1"
            [[ $RETURN_PARAM_STATUS -eq 0 ]] && PARAMETERS_ARRAY[DEBUG]="$RETURN_PARAM_OUTPUT"
            debug_mode
            shift
            ;;
        -* | --*=) # unsupported flags
            log -e "Unsupported flag '$1'" >&2
            exit 1
            ;;
        *) # preserve positional arguments
            CMD_PARAMS="$CMD_PARAMS $1"
            shift
            ;;
        esac
    done
    [[ $REQUIRED_EMPTY_PARAM_TOTAL -eq 0 ]] || { echo && exit 1; }
    eval set -- "$CMD_PARAMS"
}

debug_mode() {
    if [[ ${PARAMETERS_ARRAY[DEBUG]} == true ]]; then
        log -d "--kube-host=${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}"
        log -d "--kube-namespace=${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}"
        log -d "--kube-version=${PARAMETERS_ARRAY[DEPLOY_KUBE_VERSION]}"
        log -d "--chart-repo-url=${PARAMETERS_ARRAY[HELM_REPO_URL]}"
        log -d "--chart-repo-name=${PARAMETERS_ARRAY[CHART_REPO]}"
        log -d "--chart-name=${PARAMETERS_ARRAY[CHART_NAME]}"
        log -d "--chart-version=${PARAMETERS_ARRAY[CHART_VERSION]/-*/}"
        log -d "--release-name=${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"
        log -d "--helm-set-args=${PARAMETERS_ARRAY[HELM_SET_ARGS]}"
        log -d "--git-values-file=${PARAMETERS_ARRAY[HELM_VALUES_GIT_FILE]}"
        log -d "--git-values-custom-dir=${PARAMETERS_ARRAY[HELM_VALUES_GIT_CUSTOM_DIR]}"
        log -d "--rollback-release=${PARAMETERS_ARRAY[ROLLBACK_FAILED_RELEASE]}"
        log -d "--working-dir=${PARAMETERS_ARRAY[WORKING_DIR]}"
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
        exit 1
    else
        log -i "$HELM_REPO_ADD"
    fi
    log -i "Updating helm repo..."
    HELM_REPO_UPDATE=$(helm repo update)
    if [[ $? -ne 0 ]]; then
        log -e "$HELM_REPO_UPDATE"
        exit 1
    else
        log -i "$HELM_REPO_UPDATE"
    fi
}

parse_helm_values() {
    if [[ ${PARAMETERS_ARRAY[HELM_VALUES_GIT_FILE]} ]]; then
        # If working dir is empty we cannot get the path for the YAML file
        if [[ -z ${PARAMETERS_ARRAY[WORKING_DIR]} ]]; then
            log -e "A helm git values file was provided, but the working directory was not provided." >&2
            log -e "Cannot search for the file without a given path." >&2
            echo
            exit 127
        else
            # If custom dir is not provided it will default to the PARAMETERS_ARRAY[CHART_NAME] variable
            [[ ${PARAMETERS_ARRAY[HELM_VALUES_GIT_CUSTOM_DIR]} ]] &&
                HELM_VALUES_DIR_NAME="${PARAMETERS_ARRAY[WORKING_DIR]}/*/${PARAMETERS_ARRAY[HELM_VALUES_GIT_CUSTOM_DIR]}" ||
                HELM_VALUES_DIR_NAME="${PARAMETERS_ARRAY[WORKING_DIR]}/*/${PARAMETERS_ARRAY[CHART_NAME]}"
            # Normalize directory name. It should not contain duplicated forward slashes
            HELM_VALUES_DIR_NAME=$(echo $HELM_VALUES_DIR_NAME | sed -r -e 's/\/{2,}/\//g' -e 's/\/$//g')
            log -i "Searching for '${PARAMETERS_ARRAY[HELM_VALUES_GIT_FILE]}' file in '$HELM_VALUES_DIR_NAME' directory."
            HELM_GIT_VALUES_FILE="$(
                find $HELM_VALUES_DIR_NAME -mindepth 1 -maxdepth 1 -type f -name ${PARAMETERS_ARRAY[HELM_VALUES_GIT_FILE]} 2>/dev/null
            )"
            if [[ $HELM_GIT_VALUES_FILE ]]; then
                GIT_FILE_STATUS=$(yq eval 'true' $HELM_GIT_VALUES_FILE 2>&1 >/dev/null) || {
                    log -e "'$HELM_GIT_VALUES_FILE' helm git values file does not contain a valid YAML syntax." >&2
                    log -e "$GIT_FILE_STATUS" >&2
                    echo
                    exit 127
                }
                log -i "'$HELM_GIT_VALUES_FILE' file found. Proceeding with deployment..."
                # Return -f parameter and the final values file path and name
                HELM_GIT_VALUES_FILE=(-f "$HELM_GIT_VALUES_FILE")
            else
                log -e "'${PARAMETERS_ARRAY[HELM_VALUES_GIT_FILE]}' file could not be found." >&2
                echo
                exit 127
            fi
        fi
    fi
}

# Retrieve the yaml output of a helm release
get_yaml_output_for_helm_release() {
    HELM_YAML_OUTPUT=$(helm list --all --kube-context "${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}" --namespace "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" -o yaml 2>&1)
    if [[ $? -ne 0 ]]; then
        log -e "$HELM_YAML_OUTPUT"
        echo
        exit 94
    elif [[ $HELM_YAML_OUTPUT == [] ]]; then
        log -e "There are no helm deployments in '${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}' namespace." >&2
        echo
        exit 94
    fi

    # If both release and chart names were provided, check that the release matches with the chart name
    if [[ ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]} ]] && [[ ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        RELEASE_NAME=$(yq eval '.[] | select (.chart == "*'"${PARAMETERS_ARRAY[CHART_NAME]}"'*") |
            .name | select (. == "*'"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"'*")' - <<<"$HELM_YAML_OUTPUT")
        if [[ $RELEASE_NAME != ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]} ]]; then
            HELM_RELEASE_ARRAY=($(yq eval '.[] | select (.chart == "*'"${PARAMETERS_ARRAY[CHART_NAME]}"'*") | 
                .name as $name | $name' - <<<"$HELM_YAML_OUTPUT"))
            log -e "Release name '${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}' does not match with any release from '${PARAMETERS_ARRAY[CHART_NAME]}' chart." >&2
            log -e "Available release names in '${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}' namespace for the selected chart name: ${HELM_RELEASE_ARRAY[*]}" >&2
            echo
            exit 94
        fi
    # If the release name is present and the chart name is empty, check that release name exists in that namespace
    elif [[ ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]} ]] && [[ -z ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        RELEASE_EXISTS_IN_NS=$(yq eval '.[] | select (.name == "*'"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"'*")' - <<<"$HELM_YAML_OUTPUT")
        if [[ -z $RELEASE_EXISTS_IN_NS ]]; then
            log -e "Release name '${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}' cannot be found in '${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}' namespace." >&2
            echo
            exit 94
        fi
    fi

    # Get Release Name based on the chart name.
    # If there are multiple releases, show a warning message and stop
    if [[ -z ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]} ]] && [[ ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        log -w "Release name was not provided, auto detecting it..."
        HELM_RELEASE_ARRAY=($(yq eval '.[] | select (.chart == "*'"${PARAMETERS_ARRAY[CHART_NAME]}"'*") | 
            .name as $name | $name' - <<<"$HELM_YAML_OUTPUT"))
        if [[ ${#HELM_RELEASE_ARRAY[@]} -gt 1 ]]; then
            log -e "Multiple releases found: ${HELM_RELEASE_ARRAY[*]}" >&2
            log -e "Auto detection works if there is only one release of the chart in the provided namespace." >&2
            log -e "You must provide the release name in order to deploy the chart." >&2
            echo
            exit 94
        else
            PARAMETERS_ARRAY[HELM_RELEASE_NAME]="${HELM_RELEASE_ARRAY[*]}"
            log -i "Release name detected as: ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"
        fi
    elif [[ -z ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]} ]] && [[ -z ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        log -w "Release name was not provided, auto detecting it..."
        log -e "Release name cannot be auto detected because chart name is empty." >&2
        log -e "You must provide the chart name in order to auto detect the release name." >&2
        echo
        exit 94
    fi

    # CHART_NAME is blank. Helm release name is now required to fetch chart name.
    if [[ -z ${PARAMETERS_ARRAY[CHART_NAME]} ]]; then
        PARAMETERS_ARRAY[CHART_NAME]=$(yq eval '.[] | select (.name == "*'"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"'*") | 
            .chart as $chart | $chart' - <<<"$HELM_YAML_OUTPUT" | rev | cut -d- -f2- | rev)
        log -w "Chart name was not provided, auto detecting it..."
        log -i "Chart name detected as: ${PARAMETERS_ARRAY[CHART_NAME]}"
    fi

    # Get Chart Version based on the release name
    if [[ -z ${PARAMETERS_ARRAY[CHART_VERSION]/-*/} ]]; then
        PARAMETERS_ARRAY[CHART_VERSION]=$(yq eval '.[] | select (.name == "*'"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"'*") | 
            .chart as $chart | $chart' - <<<"$HELM_YAML_OUTPUT" | rev | cut -d- -f1 | rev)
        log -w "Chart version was not provided, auto detecting it..."
        log -i "Chart version detected as: ${PARAMETERS_ARRAY[CHART_VERSION]/-*/}"
    fi
}

check_kubernetes_connection() {
    PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]="${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}-context"
    kubectl cluster-info &>/dev/null
    if [[ $? -ne 0 ]]; then
        log -e "Cluster connection could not be established using '${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}' context." >&2
        echo
        exit 1
    else
        log -i "Cluster connection established using '${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}' context."
    fi
}

check_helm_release_status() {
    HELM_PENDING_STATUSES=("pending-rollback" "pending-upgrade" "pending-install" "uninstalling" "uninstalled" "unknown")
    HELM_RELEASE_STATUS=$(yq eval '.[] | select (.name == "*'"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"'*") |
        .status as $status | $status' - <<<"$HELM_YAML_OUTPUT")
    if [[ " ${HELM_PENDING_STATUSES[@]} " =~ " $HELM_RELEASE_STATUS " ]]; then
        log -w "Current helm release status: $HELM_RELEASE_STATUS"
        log -w "Another operation (install/upgrade/rollback) left the deployment in a pending state."
        if [[ ${PARAMETERS_ARRAY[ROLLBACK_FAILED_RELEASE]} == true ]]; then
            HELM_RELEASE_HISTORY="$(
                helm history "${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}" --namespace "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" -o yaml
            )"
            DEPLOYED_REVISION="$(yq eval '.[] | select (.status == "*deployed*") | 
                .revision as $revision | $revision' - <<<"$HELM_RELEASE_HISTORY")"
            SUPERSEDED_REVISION="$(yq eval '.[] | select (.status == "*superseded*") |
                .revision as $revision | $revision' - <<<"$HELM_RELEASE_HISTORY" | tail -n1)"
            [[ ${DEPLOYED_REVISION:-$SUPERSEDED_REVISION} ]] &&
                {
                    log -w "Trying to rollback the helm release..."
                    {
                        HELM_ROLLBACK=$(helm rollback --namespace "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" "${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}" \
                            "${DEPLOYED_REVISION:-$SUPERSEDED_REVISION}")
                        HELM_ROLLBACK_STATUS=$?
                    }
                    [[ $HELM_ROLLBACK_STATUS -eq 0 ]] &&
                        log -i "Release rolled back to the latest stable revision: ${DEPLOYED_REVISION:-$SUPERSEDED_REVISION}" ||
                        {
                            log -e "Release could not be rolled back." >&2
                            echo
                            exit 91
                        }
                } ||
                {
                    log -e "There is no stable revision to rollback to." >&2
                    echo
                    exit 91
                }
        elif [[ ${PARAMETERS_ARRAY[ROLLBACK_FAILED_RELEASE]} != true ]]; then
            log -w "In order to fix the release status automatically, you need to set rollback parameter to true."
            log -e "Helm cannot upgrade releases with status '$HELM_RELEASE_STATUS'." >&2
            echo
            exit 91
        fi
    fi
}

upgrade_helm_release() {
    check_kubernetes_connection
    get_yaml_output_for_helm_release
    helm_repo_add_and_update

    log -i "Chart Namespace: ${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}"
    log -i "Chart Name: ${PARAMETERS_ARRAY[CHART_NAME]}"
    log -i "Chart Version: ${PARAMETERS_ARRAY[CHART_VERSION]/-*/}"
    log -i "Release Name: ${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"
    [[ ${PARAMETERS_ARRAY[HELM_SET_ARGS]} ]] && log -i "Helm set parameters: ${PARAMETERS_ARRAY[HELM_SET_ARGS]}"
    [[ ${PARAMETERS_ARRAY[HELM_VALUES_GIT_FILE]} ]] && log -i "Helm values file from Git: ${PARAMETERS_ARRAY[HELM_VALUES_GIT_FILE]}"
    [[ ${PARAMETERS_ARRAY[HELM_VALUES_GIT_CUSTOM_DIR]} ]] && log -i "Helm values custom dir from Git: ${PARAMETERS_ARRAY[HELM_VALUES_GIT_CUSTOM_DIR]}"

    check_helm_release_status

    SLEEP=30
    RETRIES=3
    log -i "Upgrading helm release..."
    log -i "NOTE: Timeout is set at 5 minutes with 3 retries"
    # default timeout for helm commands is 300 seconds so no need to adjust
    INDEX=0
    until [[ $INDEX -gt $RETRIES ]]; do
        let ++INDEX
        log -i "Commencing deployment (attempt #$INDEX)..."
        parse_helm_values "${PARAMETERS_ARRAY[HELM_VALUES_RAW_GIT_URL]}"
        DEPLOYMENT_OUTPUT=$(helm upgrade --kube-context "${PARAMETERS_ARRAY[DEPLOY_KUBE_HOST]}" "${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}" \
            --namespace "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" --reuse-values "${HELM_GIT_VALUES_FILE[@]}" $DEBUG_OPTS \
            --set "${PARAMETERS_ARRAY[HELM_SET_ARGS]}" "${PARAMETERS_ARRAY[CHART_REPO]}"/"${PARAMETERS_ARRAY[CHART_NAME]}" \
            --version "${PARAMETERS_ARRAY[CHART_VERSION]/-*/}" 2>&1 >/dev/null)
        DEPLOYMENT_RESULT=$?
        if [[ ${PARAMETERS_ARRAY[DEBUG]} == true ]]; then
            log -d "$DEPLOYMENT_OUTPUT"
        fi
        if [[ $DEPLOYMENT_RESULT -ne 0 ]] && [[ $DEPLOYMENT_OUTPUT =~ "timed out" ]] && [[ $INDEX -lt $RETRIES ]]; then
            log -w "Time out reached. Retrying..."
            sleep $SLEEP
            continue
        elif [[ $DEPLOYMENT_RESULT -ne 0 ]] && [[ $DEPLOYMENT_OUTPUT =~ "timed out" ]] && [[ $INDEX -ge $RETRIES ]]; then
            log -e "Failed to achieve the helm deployment within allotted time and retry count." >&2
            log -e "Unable to deploy to '${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}'." >&2
            log -e "$DEPLOYMENT_OUTPUT" >&2
            break
        elif [[ $DEPLOYMENT_RESULT -ne 0 ]]; then
            log -e "Unable to deploy to '${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}'." >&2
            log -e "$DEPLOYMENT_OUTPUT" >&2
            break
        fi
        log -i "Deployment success."
        echo
        helm ls -n "${PARAMETERS_ARRAY[DEPLOY_KUBE_NAMESPACE]}" -f ^"${PARAMETERS_ARRAY[HELM_RELEASE_NAME]}"$
        echo
        break
    done
    [[ $DEPLOYMENT_RESULT -eq 0 ]] || { echo && exit 91; }
}

# Call all the necessary functions
echo
get_parameters "$@"
upgrade_helm_release "$@"
echo
