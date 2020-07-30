#!/bin/bash

# Supported versions are
#   ICP 3.1 - different versions of kube and helm
#   ICP 3.2 - different versions of kube, helm, and cert locations
#   OCP 4.2 + CommonServices 3.2.3 - different versions kube, helm, and cert locations

DEPLOY_TYPE=$1
DEPLOY_KUBE_VERSION=$2
DEPLOY_KUBE_NAMESPACE=$3
DEPLOY_KUBE_HOST=$4
DEPLOY_KUBE_IP=$5
DEPLOY_KUBE_PORT=8001
if [[ "$DEPLOY_KUBE_IP" =~ :[0-9]+$ ]]; then
    # TODO: add in the ability to send a full URL
    DEPLOY_KUBE_PORT=`echo $DEPLOY_KUBE_IP | rev | cut -d : -f 1 | rev`
    DEPLOY_KUBE_IP=`echo $DEPLOY_KUBE_IP | rev | cut -d : -f 2 | rev`
fi
DEPLOY_KUBE_TOKEN=$6
DEPLOY_HELM_TLS=$7
if [ "$DEPLOY_HELM_TLS" == "undefined" ]; then
    DEPLOY_HELM_TLS=true
fi

if [ "$DEBUG" == "true" ]; then
    echo "DEBUG::Script input variables..."
    echo "DEPLOY_HELM_TLS=$DEPLOY_HELM_TLS"
    echo "DEPLOY_TYPE=$DEPLOY_TYPE"
    echo "DEPLOY_KUBE_VERSION=$DEPLOY_KUBE_VERSION"
    echo "DEPLOY_KUBE_NAMESPACE=$DEPLOY_KUBE_NAMESPACE"
    echo "DEPLOY_KUBE_HOST=$DEPLOY_KUBE_HOST"
    echo "DEPLOY_KUBE_IP=$DEPLOY_KUBE_IP"
    echo "DEPLOY_KUBE_PORT=$DEPLOY_KUBE_PORT"
    echo "DEPLOY_KUBE_TOKEN=$DEPLOY_KUBE_TOKEN"
    echo "DEPLOY_HELM_TLS=$DEPLOY_HELM_TLS"
    echo "DEBUG::No Proxy variables from Helm Chart..."
    echo "NO_PROXY"=$NO_PROXY
    echo "no_proxy"=$no_proxy
    echo "DEBUG::Host Alias from Helm Chart..."
    less /etc/hosts
fi

if [ "$DEPLOY_TYPE" == "helm" ] || [ "$DEPLOY_TYPE" == "helm3" ] || [ "$DEPLOY_TYPE" == "kubernetes" ]; then
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

    # TODO: Move these variables up to the top
    KUBE_NAMESPACE=$DEPLOY_KUBE_NAMESPACE
    KUBE_CLUSTER_HOST=$DEPLOY_KUBE_HOST
    KUBE_CLUSTER_IP=$DEPLOY_KUBE_IP
    KUBE_CLUSTER_PORT=$DEPLOY_KUBE_PORT
    KUBE_TOKEN=$DEPLOY_KUBE_TOKEN

    # TODO: add ability for user to provide ca.crt or a mechanism to retrieve cert.
    # $KUBE_CLI config set-cluster $KUBE_CLUSTER_HOST --server=https://$KUBE_CLUSTER_IP:$KUBE_CLUSTER_PORT --certificate-authority="./ca.crt" --embed-certs=true
    echo "   ⋯ Configuring Kube Config..."
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
    echo " ↣ Kubernetes configuration completed."
fi

if [ "$DEPLOY_TYPE" == "helm" ]; then
    source /cli/scripts/common/initialize-dependencies-helm.sh $DEPLOY_TYPE

    if [[ $DEPLOY_HELM_TLS == "true" ]]; then
        echo "   ⋯ Configuring Helm TLS..."
        HELM_TLS_STRING='--tls'
        echo "   ↣ Helm TLS parameters configured as: $HELM_TLS_STRING"
        set -o pipefail
        echo "   ⋯ Retrieving Cluster CA certs from cluster..."
        $KUBE_CLI -n kube-system get secret cluster-ca-cert -o jsonpath='{.data.tls\.crt}' | base64 -d > $HELM_HOME/ca.pem
        if [ $? -ne 0 ]; then echo "Failure to get ca.crt" && exit 1; fi
        $KUBE_CLI -n kube-system get secret cluster-ca-cert -o jsonpath='{.data.tls\.key}' | base64 -d > $HELM_HOME/ca-key.pem
        if [ $? -ne 0 ]; then echo "Failure to get ca.key" && exit 1; fi
        echo "     ⋯ Generating Helm TLS certs..."
        openssl genrsa -out $HELM_HOME/key.pem 4096
        openssl req -new -key $HELM_HOME/key.pem -out $HELM_HOME/csr.pem -subj "/C=US/ST=New York/L=Armonk/O=IBM Cloud Private/CN=admin"
        openssl x509 -req -in $HELM_HOME/csr.pem -extensions v3_usr -CA $HELM_HOME/ca.pem -CAkey $HELM_HOME/ca-key.pem -CAcreateserial -out $HELM_HOME/cert.pem
        # Sleep is required otherwise sometimes the certificate is created prior to the service clock if there is time draft on target server.
        sleep 10
        echo "   ↣ Helm TLS configured."

        if [ "$DEBUG" == "true" ]; then
            echo "Listing Helm home folder"
            ls -ltr $HELM_HOME
            less $HELM_HOME/ca.pem
            less $HELM_HOME/cert.pem
            less $HELM_HOME/key.pem
            echo "Cert.pem Date Time: $(openssl x509 -noout -dates -in $HELM_HOME/cert.pem)"
        fi
    else
        echo "   ↣ Helm TLS disabled, skipping configuration..."
    fi
fi

if [ "$DEPLOY_TYPE" == "helm3" ]; then
    source /cli/scripts/common/initialize-dependencies-helm.sh $DEPLOY_TYPE
fi