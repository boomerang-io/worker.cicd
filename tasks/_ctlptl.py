"""
This module contains Python str.format compatible strings to generate
ctlptl configurations for different clusters providers:

https://github.com/tilt-dev/ctlptl/tree/main/examples
"""

# This configuration merges ctlptl with kind specific customizations
# found here: https://kind.sigs.k8s.io/docs/user/configuration/
KIND_DEV_CLUSTER_CTLPTL_FORMAT = """
# Creates a kind cluster with Kind's custom cluster config
# https://pkg.go.dev/sigs.k8s.io/kind/pkg/apis/config/v1alpha4#Cluster
# Creates a cluster with 2 nodes.
apiVersion: ctlptl.dev/v1alpha1
kind: Cluster
product: kind
registry: {name}-registry
kindV1Alpha4Cluster:
  name: {name}
  nodes:
    - role: control-plane
      image: kindest/node:v1.25.11
      kubeadmConfigPatches:
        - |-
          apiVersion: kubeadm.k8s.io/v1beta1
          kind: InitConfiguration
          metadata:
              name: ""
          spec:
              featureGates:
                  "ExperimentalInClusterAuthentication": true

        - |-
          kind: InitConfiguration
          nodeRegistration:
              kubeletExtraArgs:
                   node-labels: "ingress-ready=true"

    - role: worker
      image: kindest/node:v1.25.11
    - role: worker
      image: kindest/node:v1.25.11
"""

K3D_DEV_CLUSTER_CTLPTL_FORMAT = """
# Creates a k3d cluster with a registry.
# k3d with an embedded config
apiVersion: ctlptl.dev/v1alpha1
kind: Cluster
name: {name}
product: k3d
registry: {name}-registry
"""
