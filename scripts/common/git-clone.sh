#!/bin/bash

# ( printf '\n'; printf '%.0s-' {1..30}; printf ' Retrieving Source Code '; printf '%.0s-' {1..30}; printf '\n\n' )

# REPO_FOLDER=/workflow/repository
REPO_FOLDER=$1
GIT_SSH_KEY=$2
GIT_SSH_URL=$3
GIT_REPO_URL=$4
GIT_REPO_HOST=`echo "$GIT_REPO_URL" | cut -d '/' -f 3`
GIT_CLONE_URL=`echo "$GIT_SSH_URL" | tr '[:upper:]' '[:lower:]'`
GIT_COMMIT_ID=$5
GIT_LFS=false
if [ "$6" != "" ]; then
    GIT_LFS=$6
fi

echo "Git version..."
git version

if [ "$DEBUG" == "true" ]; then
    echo "REPO_FOLDER=$REPO_FOLDER"
    echo "GIT_SSH_URL=$GIT_SSH_URL"
    echo "GIT_REPO_URL=$GIT_REPO_URL"
    echo "GIT_REPO_HOST=$GIT_REPO_HOST"
    echo "GIT_CLONE_URL=$GIT_CLONE_URL"
    echo "GIT_COMMIT_ID=$GIT_COMMIT_ID"
    echo "GIT_LFS=$GIT_LFS"
fi

#Make folders if not already created
mkdir -p ~/.ssh
mkdir -p $REPO_FOLDER

# upper to lower ensures that the host is all lower case to be accepted in match to the ssh host but also the proxy
if [[ "$GIT_SSH_URL" =~ ^http.* ]]; then
    echo "Adjusting clone for http/s"
    GIT_CLONE_URL=`echo "$GIT_SSH_URL" | sed 's#^\(.*://\)\(.*\)\(\.git\)\{0,1\}$#\git@\2.git#' | sed 's/\//:/' | tr '[:upper:]' '[:lower:]'`
fi

echo "Creating Git SSH key and adjusting permissions..."
echo "$GIT_SSH_KEY" > ~/.ssh/id_rsa
chmod 700 ~/.ssh/id_rsa

GIT_REPO_HOST_ESCAPED=`echo $GIT_REPO_HOST | sed 's/\./\\\./g'`

if [[ "$HTTP_PROXY" != "" ]] && [[ ! "$NO_PROXY" =~ ($GIT_REPO_HOST_ESCAPED) ]]; then
    echo "Setting Git SSH Config with Proxy"
    cat >> ~/.ssh/config <<EOL
host $GIT_REPO_HOST
    StrictHostKeyChecking no
    IdentityFile ~/.ssh/id_rsa
    hostname $GIT_REPO_HOST
    port 22
    proxycommand socat - PROXY:$PROXY_HOST:%h:%p,proxyport=$PROXY_PORT
EOL
else
    echo "Setting Git SSH Config"
    cat >> ~/.ssh/config <<EOL
host $GIT_REPO_HOST
    StrictHostKeyChecking no
    IdentityFile ~/.ssh/id_rsa
EOL
fi

# if [ "$GIT_LFS" == "true" ]; then
#     echo "Enabling Git LFS"
#     apk add git-lfs
# fi

GIT_OPTS=
if [ "$DEBUG" == "true" ]; then
    GIT_OPTS+=--verbose
fi

echo "Repository URL:" $GIT_CLONE_URL
if [ "$GIT_CLONE_URL" == "undefined" ]; then
    echo "Repository URL is undefined."
    exit 1
fi

echo "Cloning git repository..."
git clone --progress --recurse-submodules $GIT_OPTS $GIT_CLONE_URL $REPO_FOLDER
# git clone --progress --recurse-submodules $GIT_OPTS -n $GIT_CLONE_URL $REPO_FOLDER

GIT_RC=$?
if [ $GIT_RC != 0 ]; then
    echo "Git clone repository failed"
    exit 1
fi

echo "Git clone successful"

if  [ -d "$REPO_FOLDER" ]; then
    cd $REPO_FOLDER
    if [ "$DEBUG" == "true" ]; then
        ls -ltr
    fi

    echo "Git update submodules..."
    git submodule update --init --recursive --remote --checkout --force
    GIT_RC=$?
    if [ $GIT_RC != 0 ]; then
        echo "Git update submodules failed"
        exit 1
    fi

    echo "Git checkout commit: $GIT_COMMIT_ID ..."
    git checkout --progress --recurse-submodules $GIT_COMMIT_ID
    GIT_RC=$?
    if [ $GIT_RC != 0 ]; then
        echo "Git checkout failed"
        exit 1
    fi
else
    echo "Git repository folder does not exist"
    exit 1
fi

echo "Git checkout successful"

if [ "$DEBUG" == "true" ]; then
    echo "Listing cloned files and folders..."
    ls -altR
    
    echo "Retrieving worker size..."
    df -h
fi
