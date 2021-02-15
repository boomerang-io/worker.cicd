#!/bin/bash

# Reference / Similar code can be found here: https://github.ibm.com/IBMPrivateCloud/content-tools/blob/master/travis-tools/github/bin/package.sh
# Relies on github API: https://developer.github.com/v3/repos/releases

#############
# Inputs #
#############

HELM_REPO_TYPE=`echo $1 | tr '[:upper:]' '[:lower:]'`
if [ -z "$HELM_REPO_TYPE" ]; then
    HELM_REPO_TYPE="artifactory"
fi
HELM_REPO_URL=$2
HELM_REPO_USER=$3
HELM_REPO_PASSWORD=$4
GIT_OWNER=$5
GIT_REPO=$6
GIT_COMMIT_ID=$7
HELM_INDEX_BRANCH=$8
if [ -z "$HELM_INDEX_BRANCH" ]; then
    HELM_INDEX_BRANCH="index"
fi
GIT_API_URL=https://api.github.com
INDEX_URL=${GIT_API_URL}/repos/${GIT_OWNER}/${GIT_REPO}/contents/index.yaml

if [ "$DEBUG" == "true" ]; then
    echo "HELM_REPO_TYPE=$HELM_REPO_TYPE"
    echo "HELM_REPO_URL=$HELM_REPO_URL"
    echo "HELM_REPO_USER=$HELM_REPO_USER"
    echo "HELM_REPO_PASSWORD=$HELM_REPO_PASSWORD"
    echo "GIT_OWNER=$GIT_OWNER"
    echo "GIT_REPO=$GIT_REPO"
    echo "GIT_COMMIT_ID=$GIT_COMMIT_ID"
    echo "INDEX_URL=$INDEX_URL"
fi

#############
# Functions #
#############

function github_release() {
    echo "Name: $1"
    echo "File Path: $2"
    URL=${GIT_API_URL}/repos/${GIT_OWNER}/${GIT_REPO}/releases
    echo "Release URL: $URL"
    OUTPUT=`curl -fs -H "Authorization: token $HELM_REPO_PASSWORD" -X POST $URL \
-d "
{
  \"tag_name\": \"$1\",
  \"target_commitish\": \"$GIT_COMMIT_ID\",
  \"name\": \"$1\",
  \"body\": \":robot: Boomerang CICD automated release\",
  \"draft\": false,
  \"prerelease\": false
}"`
    if [[ $? -eq 0 ]]; then
        echo "Release created for $1"
    else
        echo "Error creating release for $1. Checking if release already exists..."
        OUTPUT=`curl -fs -H "Authorization: token $HELM_REPO_PASSWORD" -X GET $URL/tags/$1`
        if [[ $? -ne 0 ]]; then
            echo "Error: Unable to create release and no release already exists."
            exit 1
        fi
    fi
    UPLOAD_URL=`echo $OUTPUT | jq .upload_url`
    echo "Upload URL: $UPLOAD_URL"
    UPLOAD_URL_REPLACER="?name=$1.tgz"
    UPLOAD_URL_REPLACED=`echo ${UPLOAD_URL/\{?name,label\}/$UPLOAD_URL_REPLACER} | tr -d '"'`
    echo "Updated Upload URL: $UPLOAD_URL_REPLACED"
    OUTPUT2=`curl -fs -H "Authorization: token $HELM_REPO_PASSWORD" -X POST -H "Content-Type: application/octet-stream" "$UPLOAD_URL_REPLACED" --upload-file "$2"`
    if [[ $? -eq 0 ]]; then
        echo "Chart ($1) uploaded to release"
    else
        echo "Error uploading chart to release ($1)"
        echo $OUTPUT2
        return
    fi
}

function github_download_index() {
    OUTPUT=`curl -fs -H "Authorization: token $HELM_REPO_PASSWORD" -X GET $INDEX_URL?ref=${HELM_INDEX_BRANCH}`
    if [[ $? -eq 0 ]]; then
        echo "Retrieved current index.yaml"
    else
        echo "Error getting current index file or does not exist"
    fi
    echo $OUTPUT | jq -r .content | openssl base64 -d -out index.yaml
    SHA=`echo $OUTPUT | jq -r .sha`
    echo "Index SHA: $SHA"
}

function github_upload_index() {
    # this must use the openssl base64 to ensure its all on one consistent line
    # Otherwise you will get a 400 bad request fro GitHub
    curl -fs -H "Authorization: token $HELM_REPO_PASSWORD" -X PUT $INDEX_URL \
-d "
{
  \"sha\": \"$SHA\",
  \"message\": \":robot: Boomerang CICD automated helm repo index update\",
  \"content\": \"$(openssl base64 -A -in index.yaml)\",
  \"branch\": \"$HELM_INDEX_BRANCH\",
  \"committer\": {
    \"name\": \"Boomerang Joe\",
    \"email\": \"boomrng@us.ibm.com\"
  }
}"
    if [[ $? -eq 0 ]]; then
        echo "Updated index.yaml"
    else
        echo "Error uploading chart repo index"
        exit 1
    fi
}

#############
# Main #
#############

chartStableDir=/data/charts/stable
chartCurrentDir=/data/charts/current
chartIndexDir=/data/charts/index
mkdir -p $chartCurrentDir
mkdir -p $chartIndexDir
if [ "$DEBUG" == "true" ]; then
    echo "Checking /data/charts folder..."
    ls -ltr /data/charts
fi

# Validate charts have correct version
for chartPackage in `ls -1 $chartStableDir/*tgz | rev | cut -f1 -d/ | rev`
do
    echo "Found: $chartPackage"
    
    # Attempt to pull down chart package from Artifactory
    chartName=`echo $chartPackage | sed 's/\(.*\)-.*/\1/'`
    chartVersion=`echo $chartPackage | rev | sed '/\..*\./s/^[^.]*\.//' | cut -d '-' -f 1 | rev`
    helm pull --version $chartVersion --destination $chartCurrentDir boomerang-charts/$chartName
    if [ -f $chartCurrentDir/$chartPackage ]; then
        # If there is an existing file, a check will be made to see if the content of the old tar and new tar are the exact same. 
        # The digest and sha of the tar are not trustworthy when containing tgz files. 
        # The code below will sort the list of files in the tgz, then decompress each file to stdout, passing the content thru sha1sum. 
        # This will produce an order sha sum of the tgz content.
        # Note: on mac replace sha1sum with shasum
        
        ls -al $chartStableDir/$chartPackage
        ls -al $chartCurrentDir/$chartPackage
        
        if [[ `tar tvf $chartStableDir/$chartPackage | rev | cut -f1 -d' ' | rev | sort -k1 | xargs -i tar -xOf $chartStableDir/$chartPackage {} | sha1sum | cut -f1 -d' '` = \
      		      `tar tvf $chartCurrentDir/$chartPackage | rev | cut -f1 -d' ' | rev | sort -k1 | xargs -i tar -xOf $chartCurrentDir/$chartPackage {} | sha1sum | cut -f1 -d' '` ]] ; then
  	        # These files are the same, and can be shipped
			echo "  Previously shipped file."
			rm -f $chartCurrentDir/$chartPackage
        elif [[ `tar tvf $chartStableDir/$chartPackage | rev | cut -f1 -d' ' | rev | sort -k1 | grep -Ev '/charts/|requirements.lock|Chart.lock' | xargs -i tar -xOf $chartStableDir/$chartPackage {} | sha1sum | cut -f1 -d' '` = \
      		      `tar tvf $chartCurrentDir/$chartPackage | rev | cut -f1 -d' ' | rev | sort -k1 | grep -Ev '/charts/|requirements.lock|Chart.lock' | xargs -i tar -xOf $chartCurrentDir/$chartPackage {} | sha1sum | cut -f1 -d' '` ]] ; then
            echo "  Previously shipped version, with acceptable source change due to subchart version difference."
            rm -f $chartCurrentDir/$chartPackage
        else
            # These files differ, but do not have a version number update
            echo "  ERROR: Same version but different content"
            exit 1
        fi
    else
        echo "  New chart version validated."
        cp $chartStableDir/$chartPackage $chartCurrentDir
    fi
done

if [ "$HELM_REPO_TYPE" == "github" ]; then
    github_download_index
fi

# Release / Upload the packages
for filename in `ls -1 $chartCurrentDir/*tgz | rev | cut -f1 -d/ | rev`
do
    if [ -f $chartCurrentDir/$filename ]; then
        echo "Pushing chart package: $filename"
        if [ "$HELM_REPO_TYPE" == "artifactory" ]; then
            curl -# --insecure -u $HELM_REPO_USER:$HELM_REPO_PASSWORD -T $chartCurrentDir/$filename "$HELM_REPO_URL/$filename"
        elif [ "$HELM_REPO_TYPE" == "github" ]; then
            RELEASE_NAME=`echo $filename | sed -r 's@^(.*)(\.tgz)$@\1@g'`
            github_release $RELEASE_NAME $chartCurrentDir/$filename
            cp $chartCurrentDir/$filename $chartIndexDir/$filename
            helm repo index --merge index.yaml --url https://github.com/${GIT_OWNER}/${GIT_REPO}/releases/download/${RELEASE_NAME} $chartIndexDir
            mv $chartIndexDir/index.yaml index.yaml
            rm $chartIndexDir/$filename
        fi
    fi
done

# Index Charts
if [ "$HELM_REPO_TYPE" == "artifactory" ]; then
    HELM_REPO_ID=`echo $HELM_REPO_URL | rev | cut -f1 -d'/' | rev`
    HELM_INDEX_URL=`echo $HELM_REPO_URL | sed -r 's@^(.*)(/\$HELM_REPO_ID)$@\1@g'`
    curl -# -u $HELM_REPO_USER:$HELM_REPO_PASSWORD -X POST "$HELM_INDEX_URL/api/helm/$HELM_REPO_ID-local/reindex"
elif [ "$HELM_REPO_TYPE" == "github" ]; then
    github_upload_index
fi
