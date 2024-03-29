#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Package Docker Image '; printf '%.0s-' {1..30}; printf '\n\n' )

IMAGE_NAME=$1
VERSION_NAME=$2
TEAM_NAME=$3
IMAGE_ORG=`echo $TEAM_NAME | sed 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]'`
# Registry Host will potentially required a NO_PROXY entry in the controller service
BUILD_ARGS=$4
DOCKER_FILE=$5
GLOBAL_REGISTRY_HOST=$6
GLOBAL_REGISTRY_PORT=$7
GLOBAL_REGISTRY_USER=$8
GLOBAL_REGISTRY_PASSWORD=$9
CUSTOM_REGISTRY_HOST=${10}
CUSTOM_REGISTRY_PORT=${11}
CUSTOM_REGISTRY_USER=${12}
CUSTOM_REGISTRY_PASSWORD=${13}

IMG_OPTS=
SKOPEO_OPTS=
# Note: currently disabled as it actually slows the build down copying out to the mounted PVC.
# if [ -d "/cache" ]; then
#     echo "Setting cache..."
#     mkdir -p /cache/img
#     # Note: Need to set permissons as if the cache has previously been saved then a different user will own
#     chmod -R 755 /cache/img 
#     IMG_OPTS+="-s /cache/img"
#     ls -ltr /cache
# fi
if [ "$DEBUG" == "true" ]; then
    echo "Enabling debug logging..."
    IMG_OPTS+="-d"
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
    /opt/bin/img login $IMG_OPTS -u=$CUSTOM_REGISTRY_USER -p=$CUSTOM_REGISTRY_PASSWORD "$CUSTOM_DOCKER_SERVER"
else
    echo "Skipping custom registry login as no username and / or password provided. "
fi
# Log into the platforms global container registry
if [ ! -z "$GLOBAL_REGISTRY_PORT" ]; then
    GLOBAL_DOCKER_SERVER="$GLOBAL_REGISTRY_HOST:$GLOBAL_REGISTRY_PORT"
else 
    GLOBAL_DOCKER_SERVER="$GLOBAL_REGISTRY_HOST"
fi
echo "Logging into Boomerang Container Registry ($GLOBAL_DOCKER_SERVER)..."
/opt/bin/img login $IMG_OPTS -u=$GLOBAL_REGISTRY_USER -p=$GLOBAL_REGISTRY_PASSWORD "$GLOBAL_DOCKER_SERVER"

# Check for custom Dockerfile path
# DOCKERFILE_OPTS=
DOCKERFILE_OPTS="--dockerfile=Dockerfile"
if [ -z "$DOCKER_FILE" ]; then
    echo "Defaulting Dockerfile..."
    DOCKER_FILE=Dockerfile
else
    # DOCKERFILE_OPTS="-f $DOCKER_FILE"
    DOCKERFILE_OPTS="--dockerfile=$DOCKER_FILE"
fi
# echo "Dockerfile: $DOCKER_FILE"

BUILD_ARGS_STRING=
if [ ! -z "$BUILD_ARGS" ]; then
    echo "Setting up container build arguments..."
    # newline is set as delimiter
    OLDIFS="$IFS"
    IFS=$'\n' # bash specific
    BUILD_ARGS_ARRAY=($BUILD_ARGS)
    for ARG in "${BUILD_ARGS_ARRAY[@]}"; do
        echo "  Build Argument: $ARG"
        BUILD_ARGS_STRING+=" --build-arg "
        BUILD_ARGS_STRING+="$ARG"
    done
    IFS="$OLDIFS"
    echo "  Build arguments set as: $BUILD_ARGS_STRING"
fi

# IMG_STATE=/data/img
# mkdir -p $IMG_STATE
if  [ -f "$DOCKER_FILE" ]; then
    /kaniko/executor --build-arg BMRG_TAG=$VERSION_NAME --build-arg https_proxy=$HTTP_PROXY --build-arg http_proxy=$HTTP_PROXY --build-arg HTTP_PROXY=$HTTP_PROXY --build-arg HTTPS_PROXY=$HTTP_PROXY --build-arg NO_PROXY=$NO_PROXY --build-arg no_proxy=$NO_PROXY ${BUILD_ARGS_STRING} $DOCKERFILE_OPTS --context=. --destination=$IMAGE_NAME:$VERSION_NAME --oci-layout-path=./image-digest
    # /opt/bin/img build -s "$IMG_STATE" -t $IMAGE_NAME:$VERSION_NAME -o "type=docker,dest=$IMAGE_NAME_$VERSION_NAME.tar" $IMG_OPTS --build-arg BMRG_TAG=$VERSION_NAME --build-arg https_proxy=$HTTP_PROXY --build-arg http_proxy=$HTTP_PROXY --build-arg HTTP_PROXY=$HTTP_PROXY --build-arg HTTPS_PROXY=$HTTP_PROXY --build-arg NO_PROXY=$NO_PROXY --build-arg no_proxy=$NO_PROXY ${BUILD_ARGS_STRING} $DOCKERFILE_OPTS .
    # /opt/bin/img build -s "$IMG_STATE" -t $IMAGE_NAME:$VERSION_NAME $IMG_OPTS --build-arg BMRG_TAG=$VERSION_NAME --build-arg https_proxy=$HTTP_PROXY --build-arg http_proxy=$HTTP_PROXY --build-arg HTTP_PROXY=$HTTP_PROXY --build-arg HTTPS_PROXY=$HTTP_PROXY --build-arg NO_PROXY=$NO_PROXY --build-arg no_proxy=$NO_PROXY --build-arg ART_USER=$ART_USER --build-arg ART_PASSWORD=$ART_PASSWORD --build-arg ART_URL=$ART_URL $DOCKERFILE_OPTS .
    RESULT=$?
    if [ $RESULT -ne 0 ] ; then
        exit 90
    fi
else
    exit 96
fi

# /opt/bin/img ls -s "$IMG_STATE" $IMG_OPTS "$IMAGE_NAME:$VERSION_NAME"
# /opt/bin/img tag -s "$IMG_STATE" $IMG_OPTS "$IMAGE_NAME:$VERSION_NAME" "$GLOBAL_REGISTRY_HOST:$GLOBAL_REGISTRY_PORT/$IMAGE_ORG/$IMAGE_NAME:$VERSION_NAME"
# /opt/bin/img ls $IMG_OPTS "$GLOBAL_REGISTRY_HOST:$GLOBAL_REGISTRY_PORT/$IMAGE_ORG/$IMAGE_NAME:$VERSION_NAME"
#img push currently returns 404 every now and then when working with docker registries
#https://github.com/genuinetools/img/issues/128?_pjax=%23js-repo-pjax-container
#/opt/bin/img push -d ${p:docker.registry.host}:${p:docker.registry.port}/${p:bmrg.org}/${p:bmrg.image.name}:${p:version.name}
# /opt/bin/img save -s "$IMG_STATE" $IMG_OPTS -o $IMAGE_NAME_$VERSION_NAME.tar "$GLOBAL_REGISTRY_HOST:$GLOBAL_REGISTRY_PORT/$IMAGE_ORG/$IMAGE_NAME:$VERSION_NAME"

if [ "$DEBUG" == "true" ]; then
    echo "Retrieving worker size..."
    /opt/bin/img du
    df -h
    ls -lhtr $IMAGE_NAME_$VERSION_NAME.tar
    # ls -ltr
    # ping -c 3 $GLOBAL_REGISTRY_HOST
fi

skopeo $SKOPEO_OPTS copy --dest-tls-verify=false docker-archive:$IMAGE_NAME_$VERSION_NAME.tar docker://"$GLOBAL_REGISTRY_HOST:$GLOBAL_REGISTRY_PORT/$IMAGE_ORG/$IMAGE_NAME:$VERSION_NAME"
RESULT=$?
if [ $RESULT -ne 0 ] ; then
    exit 90
fi
# skopeo $SKOPEO_OPTS copy --dest-tls-verify=false docker://"$IMAGE_NAME:$VERSION_NAME" docker://"$GLOBAL_REGISTRY_HOST:$GLOBAL_REGISTRY_PORT/$IMAGE_ORG/$IMAGE_NAME:$VERSION_NAME"

if [ "$DEBUG" == "true" ]; then
    echo "Retrieving worker size..."
    df -h
fi