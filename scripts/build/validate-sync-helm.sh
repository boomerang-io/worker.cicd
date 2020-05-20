#!/bin/bash

# Reference / Similar code can be found here: https://github.ibm.com/IBMPrivateCloud/content-tools/blob/master/travis-tools/github/bin/package.sh

#############
# Inputs #
#############

HELM_REPO_TYPE=$1
if [ "$HELM_REPO_TYPE" == "undefined" ]; then
    HELM_REPO_TYPE="Artifactory"
fi
HELM_REPO_URL=$2
HELM_REPO_USER=$3
HELM_REPO_PASSWORD=$4
GIT_OWNER=$5
GIT_REPO=$6
GIT_COMMIT_ID=$7

if [ "$DEBUG" == "true" ]; then
    echo "HELM_REPO_TYPE=$HELM_REPO_TYPE"
    echo "HELM_REPO_URL=$HELM_REPO_URL"
    echo "HELM_REPO_USER=$HELM_REPO_USER"
    echo "HELM_REPO_PASSWORD=$HELM_REPO_PASSWORD"
    echo "GIT_OWNER=$GIT_OWNER"
    echo "GIT_REPO=$GIT_REPO"
    echo "GIT_COMMIT_ID=$GIT_COMMIT_ID"
fi

#############
# Functions #
#############

function github_release() {
    OUTPUT=`curl -f# -H "Authorization: token $HELM_REPO_PASSWORD" -X POST https://api.github.com/repos/${GIT_OWNER}/${GIT_REPO}/releases \
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
        echo "Error creating release for $1"
        echo $OUTPUT
        return
    fi
    UPLOAD_URL=`echo $OUTPUT | jq .upload_url`
    echo "Upload URL: $UPLOAD_URL"
    UPLOAD_URL_REPLACER="?name=$1.tgz"
    UPLOAD_URL_REPLACED=`echo ${UPLOAD_URL/\{?name,label\}/$UPLOAD_URL_REPLACER} | tr -d '"'`
    echo "Updated Upload URL: $UPLOAD_URL_REPLACED"
    OUTPUT2=`curl -f# -H "Authorization: token $HELM_REPO_PASSWORD" -H "Content-Type: application/gzip" -X POST "$UPLOAD_URL_REPLACED" --data-binary @"$2"`
    if [[ $? -eq 0 ]]; then
        echo "Chart ($1) uploaded to release"
    else
        echo "Error uploading chart to release ($1)"
        echo $OUTPUT2
        return
    fi
}

function github_upload_index() {
    OUTPUT=`curl -f# -H "Authorization: token $HELM_REPO_PASSWORD" -X GET https://api.github.com/repos/${GIT_OWNER}/${GIT_REPO}/contents/index.yaml`
    if [[ $? -eq 0 ]]; then
        echo "Retrieved current index.yaml"
    else
        echo "Error getting current index file"
        echo $OUTPUT
        return
    fi
    SHA=`echo $OUTPUT | jq .sha | tr -d '"'`
    echo "Index SHA: $SHA"
    CONTENTS=`base64 -i index.yaml`
    echo "Contents: $CONTENTS"
    OUTPUT2=`curl -f# -H "Authorization: token $HELM_REPO_PASSWORD" -X PUT https://api.github.com/repos/${GIT_OWNER}/${GIT_REPO}/contents/index.yaml \
-d "
{
  \"sha\": \"$SHA\",
  \"message\": \":robot: Boomerang CICD automated helm repo index update\",
  \"content\": \"$CONTENTS\",
  \"committer\": {
    \"name\": \"Boomerang Joe\",
    \"email\": \"boomrng@us.ibm.com\"
  }
}"`
    if [[ $? -eq 0 ]]; then
        echo "Updated index.yaml"
    else
        echo "Error uploading chart repo index"
        echo $OUTPUT2
        return
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

# NOTE:
#  THe following variables are shared with helm.sh for deploy step
HELM_RESOURCE_PATH=/tmp/.helm
# END

helm repo add boomerang-charts $HELM_REPO_URL --home $HELM_RESOURCE_PATH

# Validate charts have correct version
for chartPackage in `ls -1 $chartStableDir/*tgz | rev | cut -f1 -d/ | rev`
do
    echo "Found: $chartPackage"
    
    # Attempt to pull down chart package from Artifactory
    chartName=`echo $chartPackage | sed 's/\(.*\)-.*/\1/'`
    chartVersion=`echo $chartPackage | rev | sed '/\..*\./s/^[^.]*\.//' | cut -d '-' -f 1 | rev`
    
    helm fetch --home $HELM_RESOURCE_PATH --version $chartVersion --destination $chartCurrentDir boomerang-charts/$chartName
    
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
        elif [[ `tar tvf $chartStableDir/$chartPackage | rev | cut -f1 -d' ' | rev | sort -k1 | grep -Ev '/charts/|requirements.lock' | xargs -i tar -xOf $chartStableDir/$chartPackage {} | sha1sum | cut -f1 -d' '` = \
      		      `tar tvf $chartCurrentDir/$chartPackage | rev | cut -f1 -d' ' | rev | sort -k1 | grep -Ev '/charts/|requirements.lock' | xargs -i tar -xOf $chartCurrentDir/$chartPackage {} | sha1sum | cut -f1 -d' '` ]] ; then
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

# Release / Upload the packages
for filename in `ls -1 $chartCurrentDir/*tgz | rev | cut -f1 -d/ | rev`
do
    if [ -f $chartCurrentDir/$filename ]; then
        echo "Pushing chart package: $filename to $HELM_REPO_URL/$filename"
        if [ "$HELM_REPO_TYPE" == "Artifactory" ]; then
            curl --insecure -u $HELM_REPO_USER:$HELM_REPO_USER -T $chartCurrentDir/$filename "$HELM_REPO_URL/$filename"
        elif [ "$HELM_REPO_TYPE" == "GitHub" ]; then
            RELEASE_NAME=`echo $filename | sed -e 's@^(.*)(\.tgz)$@\1@g'`
            github_release $RELEASE_NAME "$chartCurrentDir/$filename"
            cp $chartCurrentDir/$filename $chartIndexDir/$filename
            helm repo index --home $HELM_RESOURCE_PATH --merge index.yaml --url https://github.com/${GIT_OWNER}/${GIT_REPO}/releases/download/${RELEASE_NAME} $chartIndexDir
            mv $chartIndexDir/index.yaml index.yaml
            rm $chartIndexDir/$filename
        fi
    fi
done

# Index Charts
if [ "$HELM_REPO_TYPE" == "Artifactory" ]; then
    HELM_REPO_ID=`echo $HELM_REPO_URL | rev | cut -f1 -d'/' | rev`
    HELM_INDEX_URL=`echo $HELM_REPO_URL | sed -e 's@^(.*)(/\$HELM_REPO_ID)$@\1@g'`
    curl -u $HELM_REPO_USER:$HELM_REPO_USER -X POST "$HELM_INDEX_URL/api/helm/$HELM_REPO_ID-local/reindex"
elif [ "$HELM_REPO_TYPE" == "GitHub" ]; then
    github_upload_index
fi
