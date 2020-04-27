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

if [ "$DEPLOY_TYPE" == "helm" ] || [ "$DEPLOY_TYPE" == "kubernetes" ]; then
    echo " ⋯ Configuring Kubernetes..."
    echo
    export KUBE_HOME=~/.kube
    export HELM_HOME=~/.helm
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
    echo " ⋯ Configuring Helm..."
    echo
    # Forked from reference: https://github.ibm.com/ICP-DevOps/build-harness/blob/master/modules/helm/Makefile

    # NOTE
    # The following variables are shared across helm related scripts for deploy step
    HELM_VERSION=v2.12.1
    HELM_CHART_VERSION_COL=3 #the column output of helm list changed
    if [[ "$DEPLOY_KUBE_VERSION" =~ 1.[0-9]+.[0-9]+ ]]; then
        HELM_VERSION=v2.12.3
        HELM_CHART_VERSION_COL=3 #the column output of helm list changed
    fi
    # END

    HELM_PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
    HELM_ARCH=$(uname -m | sed 's/x86_64/amd64/g')
    HELM_URL=https://kubernetes-helm.storage.googleapis.com/helm-$HELM_VERSION-$HELM_PLATFORM-$HELM_ARCH.tar.gz
    HELM_CLI=$BIN_HOME/helm
    echo "   ⋯ Installing Helm $HELM_VERSION ($HELM_PLATFORM-$HELM_ARCH) from $HELM_URL"
    curl --progress-bar -fL -o /tmp/helm.tar.gz --retry 5 $HELM_URL
    tar xzf /tmp/helm.tar.gz -C /tmp
    mv /tmp/$HELM_PLATFORM-$HELM_ARCH/helm $HELM_CLI
    rm -f /tmp/helm.tar.gz
    rm -rf /tmp/$HELM_PLATFORM-$HELM_ARCH
    $HELM_CLI version --client --short
    RESULT=$?
    if [ $RESULT -ne 0 ] ; then
        echo
        echo  "   ✗ An error occurred installing Helm. Please see output for details or talk to a support representative." "error"
        echo
        exit 1
    fi
    echo "   ↣ Helm installed."

    echo "   ⋯ Initializing Helm"
    # if [[ "$DEPLOY_KUBE_VERSION" =~ 1.[0-9]+.[0-9]+ ]]; then
        $HELM_CLI init --client-only --skip-refresh
    # else
    #     $HELM_CLI init --client-only --skip-refresh --home $HELM_RESOURCE_PATH
    # fi

    echo "   ↣ Helm home set as: $(helm home)"

    # THe following variables are shared across helm related scripts for deploy step
    # ch_helm_tls_string
    HELM_RESOURCE_PATH=
    HELM_TLS_STRING=
    if [[ $DEPLOY_HELM_TLS == "true" ]]; then
        echo "   ⋯ Configuring Helm TLS..."
        # if [[ "$DEPLOY_KUBE_VERSION" =~ 1.[0-9]+.[0-9]+ ]]; then
        HELM_TLS_STRING='--tls'
        # else
        #     HELM_RESOURCE_PATH="/tmp/.helm"
        #     mkdir -p $HELM_RESOURCE_PATH
        #     HELM_TLS_STRING="--tls --tls-ca-cert $HELM_RESOURCE_PATH/ca.crt --tls-cert $HELM_RESOURCE_PATH/admin.crt --tls-key $HELM_RESOURCE_PATH/admin.key"
        # fi
        echo "   ↣ Helm TLS parameters configured as: $HELM_TLS_STRING"
    else
        echo "   ↣ Helm TLS disabled, skipping configuration..."
    fi

    if [[ $DEPLOY_HELM_TLS == "true" ]]; then
        export HELM_HOME=$(helm home)
        set -o pipefail
        echo "   ⋯ Retrieving Cluster CA certs from cluster..."
        $KUBE_CLI -n kube-system get secret cluster-ca-cert -o jsonpath='{.data.tls\.crt}' | base64 -d > $HELM_HOME/ca.pem
        if [ $? -ne 0 ]; then echo "Failure to get ca.crt" && exit 1; fi
        echo "Checking ca.crt"
        less $HELM_HOME/ca.pem
        $KUBE_CLI -n kube-system get secret cluster-ca-cert -o jsonpath='{.data.tls\.key}' | base64 -d > $HELM_HOME/ca-key.pem
        if [ $? -ne 0 ]; then echo "Failure to get ca.key" && exit 1; fi
        echo "Checking ca.key"
        less $HELM_HOME/ca-key.pem
        echo "     ⋯ Generating Helm TLS certs..."
        openssl genrsa -out $HELM_HOME/key.pem 4096
        openssl req -new -key $HELM_HOME/key.pem -out $HELM_HOME/csr.pem -subj "/C=US/ST=New York/L=Armonk/O=IBM Cloud Private/CN=admin"
        openssl x509 -req -in $HELM_HOME/csr.pem -extensions v3_usr -CA $HELM_HOME/ca.pem -CAkey $HELM_HOME/ca-key.pem -CAcreateserial -out $HELM_HOME/cert.pem
        # Sleep is required otherwise sometimes the certificate is created prior to the service clock if there is time draft on target server.
        echo "Sleeping..."
        sleep 10
        echo "   ↣ Helm TLS configured."
    fi

    if [ "$DEBUG" == "true" ]; then
        echo "Listing Helm home folder"
        ls -ltr $HELM_HOME
        less $HELM_HOME/ca.pem
        less $HELM_HOME/cert.pem
        less $HELM_HOME/key.pem
        echo "Cert.pem Date Time: $(openssl x509 -noout -dates -in $HELM_HOME/cert.pem)"
    fi
fi