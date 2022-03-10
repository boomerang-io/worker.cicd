#!/bin/bash

# Use Skopeo to copy container from one registry to another
#
# Notes:
# - Registry Hosts will potentially required a NO_PROXY entry in the controller service
# - Parameters such as Image Path are sanitized for allow characters prior to script

IMAGE_NAME=`echo $1 | tr '[:upper:]' '[:lower:]'`
IMAGE_VERSION=$2
IMAGE_PATH=$3
DESTINATION_REGISTRY_HOST=`echo $4 | sed 's/"//g'`
DESTINATION_REGISTRY_PORT=$5
DESTINATION_REGISTRY_USER=$6
DESTINATION_REGISTRY_PASSWORD=$7
DESTINATION_REGISTRY_IMAGE_PATH=$8
GLOBAL_REGISTRY_HOST=`echo $9 | sed 's/"//g'`
GLOBAL_REGISTRY_PORT=${10}
GLOBAL_REGISTRY_USER=${11}
GLOBAL_REGISTRY_PASSWORD=${12}

if [ "$DEBUG" == "true" ]; then
    echo "IMAGE_NAME=$IMAGE_NAME"
    echo "IMAGE_VERSION=$IMAGE_VERSION"
    echo "IMAGE_PATH=$IMAGE_PATH"
    echo "DESTINATION_REGISTRY_HOST=$DESTINATION_REGISTRY_HOST"
    echo "DESTINATION_REGISTRY_PORT=$DESTINATION_REGISTRY_PORT"
    echo "DESTINATION_REGISTRY_USER=$DESTINATION_REGISTRY_USER"
    echo "DESTINATION_REGISTRY_PASSWORD=$DESTINATION_REGISTRY_PASSWORD"
    echo "DESTINATION_REGISTRY_IMAGE_PATH=$DESTINATION_REGISTRY_IMAGE_PATH"
    echo "GLOBAL_REGISTRY_HOST=$GLOBAL_REGISTRY_HOST"
    echo "GLOBAL_REGISTRY_PORT=$GLOBAL_REGISTRY_PORT"
    echo "GLOBAL_REGISTRY_USER=$GLOBAL_REGISTRY_USER"
    echo "GLOBAL_REGISTRY_PASSWORD=$GLOBAL_REGISTRY_PASSWORD"
fi

IMG_OPTS=
SKOPEO_OPTS=
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    IMG_OPTS+="-d"
    SKOPEO_OPTS+="--debug "
fi

# Set source connection settings
if [ "$GLOBAL_REGISTRY_PORT" != "undefined" ]; then
    GLOBAL_DOCKER_SERVER="$GLOBAL_REGISTRY_HOST:$GLOBAL_REGISTRY_PORT"
else 
    GLOBAL_DOCKER_SERVER="$GLOBAL_REGISTRY_HOST"
fi

# Set source credentials
if [ ! -z "$GLOBAL_REGISTRY_USER" ] || [ ! -z "$GLOBAL_REGISTRY_PASSWORD" ]; then
    echo "Configuring origin container registry credentials..."
    GLOBAL_REGISTRY_CREDS="--src-creds $GLOBAL_REGISTRY_USER:$GLOBAL_REGISTRY_PASSWORD"
else
    echo "Skipping origin container registry credentials..."
    GLOBAL_REGISTRY_CREDS="--src-no-creds=true"
fi
if [ "$DEBUG" == "true" ]; then
    echo "GLOBAL_REGISTRY_CREDS: $GLOBAL_REGISTRY_CREDS"
fi

# Set Destination Connection Settings"
if [ "$DESTINATION_REGISTRY_PORT" != "undefined" ] && [ ! -z "$DESTINATION_REGISTRY_PORT" ] && [[ ! $DESTINATION_REGISTRY_HOST =~ "icr.io" ]]; then
    DESTINATION_DOCKER_SERVER="$DESTINATION_REGISTRY_HOST:$DESTINATION_REGISTRY_PORT"
else
    DESTINATION_DOCKER_SERVER="$DESTINATION_REGISTRY_HOST"
fi

# Set Destination Credentials
if [ ! -z "$DESTINATION_REGISTRY_USER" ] || [ ! -z "$DESTINATION_REGISTRY_PASSWORD" ]; then
    echo "Configuring destination container registry credentials..."
    DESTINATION_REGISTRY_CREDS="--dest-creds $DESTINATION_REGISTRY_USER:$DESTINATION_REGISTRY_PASSWORD"
else
    echo "Skipping destination container registry credentials..."
    DESTINATION_REGISTRY_CREDS="--dest-no-creds=true"
fi
if [ "$DEBUG" == "true" ]; then
    echo "DESTINATION_REGISTRY_CREDS: $DESTINATION_REGISTRY_CREDS"
fi

sleep 10

echo "Updating skopeo configuration..."
sed -i "s/default-docker:/default-docker:\n  sigstore: https:\/\/$GLOBAL_REGISTRY_HOST\/artifactory\/boomeranglib-docker/g" /etc/containers/registries.d/default.yaml
cat /etc/containers/registries.d/default.yaml
echo ""
echo "Copying from Origin to Destination..."
echo "- Origin: $GLOBAL_DOCKER_SERVER/$IMAGE_PATH/$IMAGE_NAME:$IMAGE_VERSION"
echo "- Destination: $DESTINATION_DOCKER_SERVER$DESTINATION_REGISTRY_IMAGE_PATH/$IMAGE_NAME:$IMAGE_VERSION"
echo ""
skopeo --insecure-policy $SKOPEO_OPTS copy --src-tls-verify=false --dest-tls-verify=false $GLOBAL_REGISTRY_CREDS $DESTINATION_REGISTRY_CREDS docker://$GLOBAL_DOCKER_SERVER/$IMAGE_PATH/$IMAGE_NAME:$IMAGE_VERSION docker://$DESTINATION_DOCKER_SERVER$DESTINATION_REGISTRY_IMAGE_PATH/$IMAGE_NAME:$IMAGE_VERSION
RESULT=$?
if [ $RESULT -ne 0 ] ; then
    exit 88
fi