#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Script to streamline installing an IIB image in an OpenShift cluster for testing
# Supports optionally installing an operator from the newly-created catalog source.
#

set -e

RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="openshift-operators"
DISABLE_CATALOGSOURCES="false"
INSTALL_PLAN_APPROVAL="Automatic"
OLM_CHANNEL="fast"

errorf() {
  echo -e "${RED}$1${NC}"
}

usage() {
  cat <<EOF
This script streamlines testing IIB images by configuring an OpenShift cluster to enable it to use the specified IIB image 
in a catalog. The CatalogSource is created in the openshift-operators namespaces unless '--namespace' is specified, and
is named 'iib-testingoperatorName', eg., iib-testingdevspaces or iib-testingdevworkspace-operator

Note: to compute the latest IIB image for a given operator, use ./getLatestIIBs.sh.

If IIB installation fails, see https://docs.engineering.redhat.com/display/CFC/Test and
follow steps in section "Adding Brew Pull Secret"

Usage: 
  $0 [OPTIONS]

Options:
  --iib <IIB_IMAGE>            : IIB image to install on the cluster, e.g. registry-proxy.engineering.redhat.com/rh-osbs/iib:987654
  --install-operator <NAME>    : install operator named $NAME after creating CatalogSource
  --channel <CHANNEL>          : channel to use for operator subscription if installing operator. Default: "fast"
  --manual-updates             : use "manual" InstallPlanApproval for the CatalogSource instead of "automatic" if installing operator
  --disable-default-sources    : disable default CatalogSources. Default: false 
  -n, --namespace <NAMESPACE>  : namespace to install CatalogSource into. Default: openshift-operators

DevWorkspace Operator Example:
  $0 \\
  --iib registry-proxy.engineering.redhat.com/rh-osbs/iib:998765 --install-operator devworkspace-operator --channel fast

Dev Spaces Example:
  $0 \\
  --iib registry-proxy.engineering.redhat.com/rh-osbs/iib:987654 --install-operator devspaces --channel stable

EOF
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--iib') UPSTREAM_IIB="$2"; shift 1;;
    '--install-operator') TO_INSTALL="$2"; shift 1;;
    '--channel') OLM_CHANNEL="$2"; shift 1;;
    '--manual-updates') INSTALL_PLAN_APPROVAL="Manual";;
    '--disable-default-sources') DISABLE_CATALOGSOURCES="true";;
    '-n'|'--namespace') NAMESPACE="$2"; shift 1;;
    '-h'|'--help') usage; exit 0;;
    *) echo "[ERROR] Unknown parameter is used: $1."; usage; exit 1;;
  esac
  shift 1
done

# Check that we have IIB image and use Brew mirror
if [ -z "$UPSTREAM_IIB" ]; then
  errorf "IIB image is required (specify '--iib <image>')"
  usage
  exit 1
fi
IIB_IMAGE="brew.registry.redhat.io/rh-osbs/iib:${UPSTREAM_IIB##*:}"
echo "Using iib image $IIB_IMAGE mirrored from $UPSTREAM_IIB"

# Check we're logged into a cluster
if ! oc whoami > /dev/null 2>&1; then
  errorf "Not logged into an OpenShift cluster"
  exit 1
fi

# Optionally disable all default CatalogSources, since we'll be installing from the IIB
if [ "$DISABLE_CATALOGSOURCES" == "true" ]; then
  oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources",
"value": true}]'
fi

# Grab Brew registry token and verify we can use it
BREW_TOKENS="$(curl --negotiate -u : https://employee-token-manager.registry.redhat.com/v1/tokens -s)"
if [[ $(echo "$BREW_TOKENS" | jq -r 'length') == "0" ]]; then
  errorf "No registry token configured -- make sure you've run kinit and have a token set up according to"
  errorf "the 'Adding Brew Pull Secret' section in https://docs.engineering.redhat.com/display/CFC/Test"
  exit 1
fi
if [[ $(echo "$BREW_TOKENS" | jq -r 'length') != "1" ]]; then
  echo "Multiple tokens found, using the first one"
fi

# Add image pull secret to cluster to allow pulling from brew.registry.redhat.io
TOKEN_USERNAME=$(echo "$BREW_TOKENS" | jq -r '.[0].credentials.username')
PASSWORD=$(echo "$BREW_TOKENS" | jq -r '.[0].credentials.password')
oc get secret/pull-secret -n openshift-config -o json | jq -r '.data.".dockerconfigjson"' | base64 -d > authfile
echo "$PASSWORD" | podman login --authfile authfile --username "$TOKEN_USERNAME" --password-stdin brew.registry.redhat.io
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=authfile
rm authfile

# Create project if necessary
if ! oc get project "$NAMESPACE" > /dev/null 2>&1; then
  echo "Project $NAMESPACE does not exist; creating it"
  oc new-project "$NAMESPACE"
fi

# Add ImageContentSourcePolicy to let us pull the IIB
cat <<EOF | oc apply -f -
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: brew-registry
spec:
  repositoryDigestMirrors:
  - mirrors:
    - brew.registry.redhat.io
    source: registry.redhat.io
  - mirrors:
    - brew.registry.redhat.io
    source: registry.stage.redhat.io
  - mirrors:
    - brew.registry.redhat.io
    source: registry-proxy.engineering.redhat.com
EOF

# Add CatalogSource for the IIB
# Throw it in openshift-operators to make life a little easier for now
cat <<EOF | oc apply -f - 
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: iib-testing${TO_INSTALL}
  namespace: $NAMESPACE
spec:
  sourceType: grpc
  image: ${IIB_IMAGE}
  publisher: IIB testing ${TO_INSTALL}
  displayName: IIB testing catalog ${TO_INSTALL} 
EOF

if [ -z "$TO_INSTALL" ]; then
  echo "Done"
  exit 0
fi

# Create OperatorGroup to allow installing all-namespaces operators in $NAMESPACE
if [[ "$NAMESPACE" != "openshift-operators" ]]; then
  echo "Using custom namespace for install; creating OperatorGroup to allow all-namespaces operators to be installed"
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: $NAMESPACE-operators
  namespace: $NAMESPACE
EOF
fi

# Create subscription for operator
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: $TO_INSTALL
  namespace: $NAMESPACE
spec:
  channel: $OLM_CHANNEL
  installPlanApproval: $INSTALL_PLAN_APPROVAL
  name: $TO_INSTALL
  source: iib-testing${TO_INSTALL}
  sourceNamespace: $NAMESPACE
EOF
