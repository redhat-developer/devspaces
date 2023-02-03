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
# Requires: oc, jq, curl
# Optional: podman (for brew.registry secret)

set -e

RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="openshift-operators"
DISABLE_CATALOGSOURCES="false"
INSTALL_PLAN_APPROVAL="Automatic"
OLM_CHANNEL="fast"

# default ICSP to use to resolve unreleased images
# if using --fast or --quay flag, this will be changed to quay.io
# if using --brew flag, this will be changed to brew.registry.redhat.io
# if you want your own registry here, use --icsp flag to specify it
ICSP_URLs=""

errorf() {
  echo -e "${RED}$1${NC}"
}

usage() {
echo "
This script streamlines testing IIB images by configuring an OpenShift cluster to enable it to use the specified IIB image
in a catalog. The CatalogSource is created in the openshift-operators namespaces unless '--namespace' is specified, and
is named 'operatorName-channelName', eg., devspaces-stable or devworkspace-operator-fast

Note: to compute the latest IIB image for a given operator, use ./getLatestIIBs.sh.

If IIB installation fails, see https://docs.engineering.redhat.com/display/CFC/Test and
follow steps in section 'Adding Brew Pull Secret'

Usage:
  $0 [OPTIONS]

Options:
  --iib <IIB_IMAGE>            : IIB image to install on the cluster; could be in the form:
                               : * registry-proxy.engineering.redhat.com/rh-osbs/iib:987654 [RH internal],
                               : * brew.registry.redhat.io/rh-osbs/iib:987654 [RH public, auth required], or
                               : * quay.io/devspaces/iib:3.2-v4.11-987654 or quay.io/devspaces/iib:next-v4.10 [public]
  --install-operator <NAME>    : Install operator named $NAME after creating CatalogSource
  --channel <CHANNEL>          : Channel to use for operator subscription if installing operator. Default: "fast"
  --manual-updates             : Use "manual" InstallPlanApproval for the CatalogSource instead of "automatic" if installing operator
  --disable-default-sources    : Disable default CatalogSources. Default: false
  --quay                       : Resolve images from quay.io using ImageContentSourcePolicy
  --brew                       : Resolve images from brew.registry.redhat.io using ImageContentSourcePolicy (requires authentication)
  --icsp                       : Install using specified registry in ImageContentSourcePolicy
  -n, --namespace <NAMESPACE>  : Namespace to install CatalogSource into. Default: openshift-operators

DevWorkspace Operator Example:
  $0 \\
  --iib registry-proxy.engineering.redhat.com/rh-osbs/iib:998765 --install-operator devworkspace-operator --channel fast

Dev Spaces Example:
  $0 \\
  --iib registry-proxy.engineering.redhat.com/rh-osbs/iib:987654 --install-operator devspaces --channel stable
"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--iib') UPSTREAM_IIB="$2"; shift 1;;
    '--install-operator') TO_INSTALL="$2"; shift 1;;
    '--channel') OLM_CHANNEL="$2"; shift 1;;
    '--manual-updates') INSTALL_PLAN_APPROVAL="Manual";;
    '--disable-default-sources') DISABLE_CATALOGSOURCES="true";;
    '--icsp') ICSP_URLs="${ICSP_URLs} $2"; shift 1;;
    '--quay') ICSP_URLs="${ICSP_URLs} quay.io";;
    '--brew') ICSP_URLs="${ICSP_URLs} brew.registry.redhat.io";;
    '-n'|'--namespace') NAMESPACE="$2"; shift 1;;
    '-h'|'--help') usage; exit 0;;
    *) echo "[ERROR] Unknown parameter is used: $1."; usage; exit 1;;
  esac
  shift 1
done

# minimum requirements
if [[ ! $(command -v oc) ]]; then
  errorf "Please install oc 4.10+ from an RPM or https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"
  exit 1
fi
if [[ ! $(command -v jq) ]]; then
  errorf "Please install jq 1.2+ from an RPM or https://pypi.org/project/jq/"
  exit 1
fi
if [[ ! $(command -v curl) ]]; then
  errorf "Please install curl"
  exit 1
fi


# Check that we have IIB image and use Brew mirror
if [ -z "$UPSTREAM_IIB" ]; then
  errorf "IIB image is required (specify '--iib <image>')"
  usage
  exit 1
fi
if [[ $UPSTREAM_IIB == "registry-proxy.engineering.redhat.com/rh-osbs/iib:"* ]]; then
  IIB_IMAGE="brew.registry.redhat.io/rh-osbs/iib:${UPSTREAM_IIB##*:}"
  echo "[INFO] Using iib $TO_INSTALL image $IIB_IMAGE mirrored from $UPSTREAM_IIB"
else
  echo "[INFO] Using iib $TO_INSTALL image $UPSTREAM_IIB"
  IIB_IMAGE="${UPSTREAM_IIB}"
fi

# optional requirements (for brew.registry secret)
if [[ "${IIB_IMAGE}" == "brew.registry"* ]] && [[ ! $(command -v podman) ]]; then
  errorf "Please install podman to login to brew.registry.redhat.io, or use --iib to specify an IIB from a registry that doesn't require login"
  exit 1
fi

# Check we're logged into a cluster
if ! oc whoami > /dev/null 2>&1; then
  errorf "Not logged into an OpenShift cluster"
  exit 1
fi

# Optionally disable all default CatalogSources, since we'll be installing from the IIB
if [ "$DISABLE_CATALOGSOURCES" == "true" ]; then
  echo "[INFO] Disable default catalog sources"
  oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
fi

if [[ "${IIB_IMAGE}" == "brew.registry"* ]]; then
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
  # CRW-3463 can use podman login --tls-verify=false to work around 'certificate signed by unknown authority'
  echo "$PASSWORD" | podman login --authfile authfile --username "$TOKEN_USERNAME" --password-stdin brew.registry.redhat.io
  oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=authfile
  rm authfile
fi

# Create project if necessary
if ! oc get project "$NAMESPACE" > /dev/null 2>&1; then
  echo "Project $NAMESPACE does not exist; creating it"
  oc new-project "$NAMESPACE"
fi

TMPDIR=$(mktemp -d)

# Add ImageContentSourcePolicy to let us pull the IIB
if [[ $ICSP_URLs ]]; then
  for ICSP_URL in $ICSP_URLs; do
    echo "apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: ${ICSP_URL//./-}
spec:
  repositoryDigestMirrors:

  ## 0. general repo mappings

  - mirrors:
    - ${ICSP_URL}
    source: registry.redhat.io
  - mirrors:
    - ${ICSP_URL}
    source: registry.stage.redhat.io
  - mirrors:
    - ${ICSP_URL}
    source: registry-proxy.engineering.redhat.com

  ### now add mappings to resolve internal references
  - mirrors:
    - registry.redhat.io
    source: registry.stage.redhat.io
  - mirrors:
    - registry.stage.redhat.io
    source: registry-proxy.engineering.redhat.com
  - mirrors:
    - registry.redhat.io
    source: registry-proxy.engineering.redhat.com

  ## 1. add mappings for DevWorkspace Operator (DWO)

  ### note that in quay, the org is /devfile/ but on redhat.io, it's /devworkspace/ ... so just in case, add both mappings
  - mirrors:
    - ${ICSP_URL}/devfile/devworkspace-operator-bundle
    source: registry.redhat.io/devworkspace/devworkspace-operator-bundle
  - mirrors:
    - ${ICSP_URL}/devfile/devworkspace-operator-bundle
    source: registry.stage.redhat.io/devworkspace/devworkspace-operator-bundle
  - mirrors:
    - ${ICSP_URL}/devfile/devworkspace-operator-bundle
    source: registry-proxy.engineering.redhat.com/rh-osbs/devworkspace-operator-bundle

  ### note that in quay, the org is /devfile/ but on redhat.io, it's /devworkspace/ ... so just in case, add both mappings
  - mirrors:
    - ${ICSP_URL}/devworkspace/devworkspace-operator-bundle
    source: registry.redhat.io/devworkspace/devworkspace-operator-bundle
  - mirrors:
    - ${ICSP_URL}/devworkspace/devworkspace-operator-bundle
    source: registry.stage.redhat.io/devworkspace/devworkspace-operator-bundle
  - mirrors:
    - ${ICSP_URL}/devworkspace/devworkspace-operator-bundle
    source: registry-proxy.engineering.redhat.com/rh-osbs/devworkspace-operator-bundle

  ### now add mappings to resolve internal references
  - mirrors:
    - registry.redhat.io/devworkspace/devworkspace-operator-bundle
    source: registry.stage.redhat.io/devworkspace/devworkspace-operator-bundle
  - mirrors:
    - registry.stage.redhat.io/devworkspace/devworkspace-operator-bundle
    source: registry-proxy.engineering.redhat.com/rh-osbs/devworkspace-operator-bundle
  - mirrors:
    - registry.redhat.io/devworkspace/devworkspace-operator-bundle
    source: registry-proxy.engineering.redhat.com/rh-osbs/devworkspace-operator-bundle

  ## 2. add mappings for Dev Spaces Operator (DS)

  - mirrors:
    - ${ICSP_URL}/devspaces/devspaces-operator-bundle
    source: registry.redhat.io/devspaces/devspaces-operator-bundle
  - mirrors:
    - ${ICSP_URL}/devspaces/devspaces-operator-bundle
    source: registry.stage.redhat.io/devspaces/devspaces-operator-bundle
  - mirrors:
    - ${ICSP_URL}/devspaces/devspaces-operator-bundle
    source: registry-proxy.engineering.redhat.com/rh-osbs/devspaces-operator-bundle

  ### now add mappings to resolve internal references
  - mirrors:
    - registry.redhat.io/devspaces/devspaces-operator-bundle
    source: registry.stage.redhat.io/devspaces/devspaces-operator-bundle
  - mirrors:
    - registry.stage.redhat.io/devspaces/devspaces-operator-bundle
    source: registry-proxy.engineering.redhat.com/rh-osbs/devspaces-operator-bundle
  - mirrors:
    - registry.redhat.io/devspaces/devspaces-operator-bundle
    source: registry-proxy.engineering.redhat.com/rh-osbs/devspaces-operator-bundle
" > $TMPDIR/ImageContentSourcePolicy_${ICSP_URL}.yml && oc apply -f $TMPDIR/ImageContentSourcePolicy_${ICSP_URL}.yml
  done
fi

# Add CatalogSource for the IIB
# Throw it in openshift-operators to make life a little easier for now
if [ -z "$TO_INSTALL" ]; then
  CATALOGSOURCE_NAME="iib-${UPSTREAM_IIB##*:}-${OLM_CHANNEL}"
else
  CATALOGSOURCE_NAME="${TO_INSTALL}-${OLM_CHANNEL}"
fi
echo "apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${CATALOGSOURCE_NAME}
  namespace: $NAMESPACE
spec:
  sourceType: grpc
  image: ${IIB_IMAGE}
  publisher: IIB testing ${TO_INSTALL}
  displayName: IIB testing catalog ${TO_INSTALL}
" > $TMPDIR/CatalogSource.yml && oc apply -f $TMPDIR/CatalogSource.yml

if [ -z "$TO_INSTALL" ]; then
  echo "Done"
  exit 0
fi

# Create OperatorGroup to allow installing all-namespaces operators in $NAMESPACE
if [[ "$NAMESPACE" != "openshift-operators" ]]; then
  echo "Using custom namespace for install; creating OperatorGroup to allow all-namespaces operators to be installed"
echo "apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: $NAMESPACE-operators
  namespace: $NAMESPACE
" > $TMPDIR/OperatorGroup.yml && oc apply -f $TMPDIR/OperatorGroup.yml
fi

# Create subscription for operator
echo "apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: $TO_INSTALL
  namespace: $NAMESPACE
spec:
  channel: $OLM_CHANNEL
  installPlanApproval: $INSTALL_PLAN_APPROVAL
  name: $TO_INSTALL
  source: ${TO_INSTALL}-${OLM_CHANNEL}
  sourceNamespace: $NAMESPACE
" > $TMPDIR/Subscription.yml && oc apply -f $TMPDIR/Subscription.yml

# cleanup temp yaml files
rm -fr $TMPDIR
