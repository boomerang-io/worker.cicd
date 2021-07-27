#!/busybox/sh

# Validates and adjusts the parameters and then calls Kaniko for container build
#
# Notes: 
# - This script is embedded in the Tekton Task script element
# - It is not directly referenced or used inside the worker 

mkdir -p /kaniko/.docker

# Check for custom registry port
if [ ! -z "$(params.buildContainerRegistryPort)" ]; then
    CUSTOM_REGISTRY_SERVER="$(params.buildContainerRegistryHost):$(params.buildContainerRegistryPort)"
else
    CUSTOM_REGISTRY_SERVER="$(params.buildContainerRegistryHost)"
fi
# Log into custom registry if needed
if [ ! -z "$(params.buildContainerRegistryUser)" ] || [ ! -z "$(params.buildContainerRegistryPassword)" ]; then
    echo "Creating Custom Registry Config ($CUSTOM_REGISTRY_SERVER)..."
    echo "{\"auths\":{\"${CUSTOM_REGISTRY_SERVER}\":{\"username\":\"$(params.buildContainerRegistryUser)\",\"password\":\"$(params.buildContainerRegistryPassword)\"}}}" > /kaniko/.docker/config.json
    less /kaniko/.docker/config.json
else
    echo "Skipping custom registry login as no username and / or password provided. "
fi

if [ ! -z "$(params.globalContainerRegistryPort)" ]; then
    GLOBAL_REGISTRY_SERVER="$(params.globalContainerRegistryHost):$(params.globalContainerRegistryPort)"
else
    GLOBAL_REGISTRY_SERVER="$(params.globalContainerRegistryHost)"
fi

echo "Building container (${GLOBAL_REGISTRY_SERVER}/$(params.imagePath)/$(params.imageName):$(params.imageVersion))..."
/kaniko/executor $(params.buildArgs) --dockerfile=$(params.dockerfile) --context=$(params.workingDir)/repository --destination=${GLOBAL_REGISTRY_SERVER}/$(params.imagePath)/$(params.imageName):$(params.imageVersion) --tarPath=$(params.workingDir)/repository/$(params.imageName)_$(params.imageVersion).tar --verbosity=debug
RESULT=$?
if [ $RESULT -ne 0 ] ; then
    exit 1
fi

if [ "$DEBUG" == "true" ]; then
    echo "Retrieving worker size..."
    df -h
    ls -lhtr $(params.workingDir)/repository/$(params.imageName)_$(params.imageVersion).tar
fi