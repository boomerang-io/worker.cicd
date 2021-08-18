#!/bin/bash

# Uses Skopeo to put TAR of a container into a registry
#
# Notes:
# - Registry Hosts will potentially required a NO_PROXY entry in the controller service
# - Parameters such as Image Path are sanitized for allow characters prior to script

IMAGE_NAME=$1
IMAGE_VERSION=$2
IMAGE_PATH=$3
GLOBAL_REGISTRY_HOST=$4
GLOBAL_REGISTRY_PORT=$5
GLOBAL_REGISTRY_USER=$6
GLOBAL_REGISTRY_PASSWORD=$7
CUSTOM_REGISTRY_HOST=$8
CUSTOM_REGISTRY_PORT=$9
CUSTOM_REGISTRY_USER=${10}
CUSTOM_REGISTRY_PASSWORD=${11}

if [ "$DEBUG" == "true" ]; then
    echo "IMAGE_NAME=$IMAGE_NAME"
    echo "IMAGE_VERSION=$IMAGE_VERSION"
    echo "IMAGE_PATH=$IMAGE_PATH"
    echo "GLOBAL_REGISTRY_HOST=$GLOBAL_REGISTRY_HOST"
    echo "GLOBAL_REGISTRY_PORT=$GLOBAL_REGISTRY_PORT"
    echo "GLOBAL_REGISTRY_USER=$GLOBAL_REGISTRY_USER"
    echo "GLOBAL_REGISTRY_PASSWORD=$GLOBAL_REGISTRY_PASSWORD"
    echo "CUSTOM_REGISTRY_HOST=$CUSTOM_REGISTRY_HOST"
    echo "CUSTOM_REGISTRY_PORT=$CUSTOM_REGISTRY_PORT"
    echo "CUSTOM_REGISTRY_USER=$CUSTOM_REGISTRY_USER"
    echo "CUSTOM_REGISTRY_PASSWORD=$CUSTOM_REGISTRY_PASSWORD"
fi

SKOPEO_OPTS=
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    SKOPEO_OPTS+="--debug "
fi

if [ ! -z "$CUSTOM_REGISTRY_PORT" ]; then
    CUSTOM_DOCKER_SERVER="$CUSTOM_REGISTRY_HOST:$CUSTOM_REGISTRY_PORT"
else 
    CUSTOM_DOCKER_SERVER="$CUSTOM_REGISTRY_HOST"
fi
# Log into custom repository if needed
if [ ! -z "$CUSTOM_REGISTRY_USER" ] || [ ! -z "$CUSTOM_REGISTRY_PASSWORD" ]; then
    echo "Logging into Custom Container Registry ($CUSTOM_DOCKER_SERVER)..."
    skopeo login $IMG_OPTS -u=$CUSTOM_REGISTRY_USER -p=$CUSTOM_REGISTRY_PASSWORD "$CUSTOM_DOCKER_SERVER"
else
    echo "Skipping custom registry login as no username and / or password provided. "
fi
# Log into the platforms global container registry
if [ ! -z "$GLOBAL_REGISTRY_PORT" ]; then
    GLOBAL_DOCKER_SERVER="$GLOBAL_REGISTRY_HOST:$GLOBAL_REGISTRY_PORT"
else 
    GLOBAL_DOCKER_SERVER="$GLOBAL_REGISTRY_HOST"
fi
# Set Destination Credentials
if [ ! -z "$GLOBAL_REGISTRY_USER" ] || [ ! -z "$GLOBAL_REGISTRY_PASSWORD" ]; then
    echo "Configuring destination container registry credentials..."
    DESTINATION_REGISTRY_CREDS="--dest-creds $GLOBAL_REGISTRY_USER:$GLOBAL_REGISTRY_PASSWORD"
else
    echo "Skipping destination container registry credentials..."
    DESTINATION_REGISTRY_CREDS="--dest-no-creds=true"
fi

skopeo $SKOPEO_OPTS copy --dest-tls-verify=false $DESTINATION_REGISTRY_CREDS docker-archive:${IMAGE_NAME}.tar docker://"$GLOBAL_REGISTRY_HOST:$GLOBAL_REGISTRY_PORT/$IMAGE_PATH/$IMAGE_NAME:$IMAGE_VERSION"
RESULT=$?
if [ $RESULT -ne 0 ] ; then
    exit 90
fi

if [ "$DEBUG" == "true" ]; then
    echo "Retrieving worker size..."
    df -h
fi