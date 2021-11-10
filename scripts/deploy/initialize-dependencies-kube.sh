#!/bin/bash

DEPLOY_KUBE_VERSION=$1
DEPLOY_KUBE_NAMESPACE=$2
DEPLOY_KUBE_HOST=$3
DEPLOY_KUBE_IP=$4
DEPLOY_KUBE_PORT=8001
if [[ "$DEPLOY_KUBE_IP" =~ :[0-9]+$ ]]; then
    # TODO: add in the ability to send a full URL
    DEPLOY_KUBE_PORT=`echo $DEPLOY_KUBE_IP | rev | cut -d : -f 1 | rev`
    DEPLOY_KUBE_IP=`echo $DEPLOY_KUBE_IP | rev | cut -d : -f 2 | rev`
fi
DEPLOY_KUBE_TOKEN=$5

if [ "$DEBUG" == "true" ]; then
    echo "DEBUG::Script input variables..."
    echo "DEPLOY_KUBE_VERSION=$DEPLOY_KUBE_VERSION"
    echo "DEPLOY_KUBE_NAMESPACE=$DEPLOY_KUBE_NAMESPACE"
    echo "DEPLOY_KUBE_HOST=$DEPLOY_KUBE_HOST"
    echo "DEPLOY_KUBE_IP=$DEPLOY_KUBE_IP"
    echo "DEPLOY_KUBE_PORT=$DEPLOY_KUBE_PORT"
    echo "DEPLOY_KUBE_TOKEN=$DEPLOY_KUBE_TOKEN"
    echo "DEBUG::No Proxy variables from Helm Chart..."
    echo "NO_PROXY"=$NO_PROXY
    echo "no_proxy"=$no_proxy
fi

echo " ⋯ Configuring Kubernetes..."
echo
export KUBE_HOME=~/.kube
BIN_HOME=/usr/local/bin
KUBE_CLI=$BIN_HOME/kubectl
if [[ "$DEPLOY_KUBE_VERSION" =~ 1.[0-9]+.[0-9]+ ]]; then
    KUBE_CLI_VERSION=v$DEPLOY_KUBE_VERSION
else
    echo "Defaulting kubectl version..."
    KUBE_CLI_VERSION=v1.13.5 #ICP 3.2.1
fi

# Relies on proxy settings coming through if there is a proxy
# echo "Using Kubectl version from the Clusters Common Services."
# curl -kL https://icp-console.apps.$DEPLOY_KUBE_HOST:443/api/cli/kubectl-linux-amd64 -o $KUBE_CLI && chmod +x $KUBE_CLI
echo "   ⋯ Installing kubectl $KUBE_CLI_VERSION (linux-amd64)..."
curl --progress-bar -fL -o $KUBE_CLI --retry 5 https://storage.googleapis.com/kubernetes-release/release/$KUBE_CLI_VERSION/bin/linux/amd64/kubectl  && chmod +x $KUBE_CLI

echo "Installing oc cli ..."
curl --progress-bar -fL -o openshift-client-linux.tar.gz https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz
tar xvzf openshift-client-linux.tar.gz
ls -al ./oc
./oc version

# TODO: Move these variables up to the top
KUBE_NAMESPACE=$DEPLOY_KUBE_NAMESPACE
KUBE_CLUSTER_HOST=$DEPLOY_KUBE_HOST
KUBE_CLUSTER_IP=$DEPLOY_KUBE_IP
KUBE_CLUSTER_PORT=$DEPLOY_KUBE_PORT
KUBE_TOKEN=$DEPLOY_KUBE_TOKEN

# TODO: add ability for user to provide ca.crt or a mechanism to retrieve cert.
# $KUBE_CLI config set-cluster $KUBE_CLUSTER_HOST --server=https://$KUBE_CLUSTER_IP:$KUBE_CLUSTER_PORT --certificate-authority="./ca.crt" --embed-certs=true

echo "   ⋯ Configuring Kube Config..."
if [[ "$KUBE_CLUSTER_HOST" == *intranet.ibm.com ]] ; then
  echo "Authenticating with username and password ..."
  KUBE_CLUSTER_USERNAME=`echo $KUBE_TOKEN | cut -d':' -f1`
  KUBE_CLUSTER_PASSWORD=`echo $KUBE_TOKEN | cut -d':' -f2`

  ./oc login --username=$KUBE_CLUSTER_USERNAME --password=$KUBE_CLUSTER_PASSWORD --server=https://$KUBE_CLUSTER_IP:$KUBE_CLUSTER_PORT --insecure-skip-tls-verify=true

  RESULT=$?
  if [ $RESULT -ne 0 ] ; then
      echo "Sleeping 5 minutes ..."
      sleep 600
      echo
      echo  "   ✗ An error occurred configuring kube config. Please see output for details or talk to a support representative." "error"
      echo
      exit 1
  fi
else
  echo "Authenticating with token ..."

  $KUBE_CLI config set-cluster $KUBE_CLUSTER_HOST --server=https://$KUBE_CLUSTER_IP:$KUBE_CLUSTER_PORT --insecure-skip-tls-verify=true && \
  $KUBE_CLI config set-credentials $KUBE_CLUSTER_HOST-user --token=$KUBE_TOKEN && \
  $KUBE_CLI config set-context $KUBE_CLUSTER_HOST-context --cluster=$KUBE_CLUSTER_HOST --user=$KUBE_CLUSTER_HOST-user --namespace=$KUBE_NAMESPACE && \
  $KUBE_CLI config use-context $KUBE_CLUSTER_HOST-context
  RESULT=$?
  if [ $RESULT -ne 0 ] ; then
      echo
      echo  "   ✗ An error occurred configuring kube config. Please see output for details or talk to a support representative." "error"
      echo
      exit 1
  fi
fi

echo " ↣ Kubernetes configuration completed."
