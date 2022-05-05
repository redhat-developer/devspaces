#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# script to automatically install Dev Spaces from the latest IIB image
# Basically a wrapper on getLatestIIBs.sh and installCatalogSourceFromIIB.sh
# Note: this script requires
# 1. You are logged into an OpenShift cluster (with cluster-admin permissions)
# 2. You an active kerberos token (kinit <username>@IPA.REDHAT.COM)
# 3. You've set up a Brew registry token

set -e

RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
NAMESPACE="openshift-operators"
CREATE_CHECLUSTER="true"

errorf() {
  echo -e "${RED}Error: $1${NC}"
}

usage() {
  cat <<EOF

This script will
1. Get the latest IIB image for a specified OpenShift and Dev Spaces version
2. Create a CatalogSource in an OpenShift Cluster
3. Install the Dev Spaces Operator from the new CatalogSource
4. Create a CheCluster to install Dev Spaces

Usage: $0 [OPTIONS]

Options:
  -t <DS_VERSION>     : Dev Spaces version to test, e.g. '3.0'. Required.
  -n <NAMESPACE>      : Namespace to install everything into. Default: openshift-operators
  --checluster <PATH> : use CheCluster yaml defined at path instead of default. Optional
  --no-checluster     : Do not create CheCluster (use dsctl later to create a custom one)
  --get-url           : Wait for Dev Spaces to install and print URL for dashboard.
EOF
}

# Check we're logged into everything we need
preflight() {
  if [ -z "$DS_VERSION" ]; then
    errorf "Dev Spaces version is required (see '-t' parameter)"
    usage
    exit 1
  fi
  if ! oc whoami > /dev/null 2>&1; then
    errorf "Not logged into an OpenShift cluster"
    exit 1
  fi
  BREW_TOKENS_NUM="$(curl --negotiate -u : https://employee-token-manager.registry.redhat.com/v1/tokens -s | jq -r 'length')"
  if [[ "$BREW_TOKENS_NUM" == "0" ]]; then
    errorf "No registry token configured -- make sure you've run kinit and have a token set up according to"
    errorf "the 'Adding Brew Pull Secret' section in https://docs.engineering.redhat.com/display/CFC/Test"
    exit 1
  fi
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') DS_VERSION="$2"; shift 1;;
    '-n') NAMESPACE="$2"; shift 1;;
    '--checluster') CHECLUSTER_PATH="$2"; shift 1;;
    '--no-checluster') CREATE_CHECLUSTER="false";;
    '--get-url') GET_URL="true";;
    '-h'|'--help') usage; exit 0;;
  esac
  shift 1
done

preflight

OPENSHIFT_VER=$(oc version -o json | jq -r '.openshiftVersion | scan("^[0-9].[0-9]+")')
echo "Detected OpenShift version v$OPENSHIFT_VER"

LATEST_IIB=$("$SCRIPT_DIR"/getLatestIIBs.sh -t "$DS_VERSION" -o "$OPENSHIFT_VER" -q)
echo "Found latest IIB $LATEST_IIB"

"$SCRIPT_DIR"/installCatalogSourceFromIIB.sh \
  --iib "$LATEST_IIB" \
  --install-operator "devspaces" \
  --channel "stable" \
  --namespace "$NAMESPACE"

if [[ "$CREATE_CHECLUSTER" == "false" ]]; then
  echo "Not creating CheCluster -- all done"
  exit 0
fi

echo "Waiting for CheCluster CRs to be available in the cluster. Timeout is 3 minutes."
for _ in {1..60}; do
  echo -n '.'
  oc get crd checlusters.org.eclipse.che > /dev/null 2>&1 && break
  sleep 3
done
echo ""

if ! oc get crd checlusters.org.eclipse.che > /dev/null 2>&1; then
  errorf "Dev Spaces operator install not completed within 3 minutes; giving up"
  exit 1
fi

# TODO: add support for custom patch YAML
if [ -z "$CHECLUSTER_PATH" ]; then
  cat <<EOF | oc apply -f -
apiVersion: org.eclipse.che/v1
kind: CheCluster
metadata:
  name: devspaces
  namespace: $NAMESPACE
spec: {}
EOF
else
  oc apply -f "$CHECLUSTER_PATH"
fi

if [[ $GET_URL != "true" ]]; then
  echo "All done"
  exit 0
fi

echo "Waiting for Dev Spaces to install in the cluster. Timeout is 15 minutes."
for _ in {1..300}; do
  echo -n '.'
  STATUS=$(oc get checlusters devspaces -n "$NAMESPACE" -o json | jq -r '.status.cheClusterRunning')
  if [[ "$STATUS" == "Available" ]]; then
    break
  fi
  sleep 3
done
echo ""

if [[ "$STATUS" != "Available" ]]; then
  echo "Dev Spaces did not become available before timeout expired"
else
  echo "Dev Spaces is installed"
fi

CHECLUSTER_JSON=$(oc get checlusters devspaces -n "$NAMESPACE" -o json)
cat <<EOF
Dashboard URL..............$(echo "$CHECLUSTER_JSON" | jq -r '.status.cheURL')
Devfile registry URL.......$(echo "$CHECLUSTER_JSON" | jq -r '.status.devfileRegistryURL')
Plugin registry URL........$(echo "$CHECLUSTER_JSON" | jq -r '.status.pluginRegistryURL')
Workspaces base domain.....$(echo "$CHECLUSTER_JSON" | jq -r '.status.devworkspaceStatus.workspaceBaseDomain')
EOF
