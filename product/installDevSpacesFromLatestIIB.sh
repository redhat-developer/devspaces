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
GET_URL="true"

errorf() {
  echo -e "${RED}Error: $1${NC}"
}

usage() {
  cat <<EOF

This script will
0. Log into the specified cluster using kubeadmin user & cluster API URL, if provided
1. Get the latest IIB image for specified Dev Spaces version and detected OpenShift version
2. Create a CatalogSource in an OpenShift Cluster
3. Install the Dev Spaces Operator from the new CatalogSource
4. Create 10 dummy OpenShift users from user1 to user10
5. Create a CheCluster to install Dev Spaces

Usage: $0 [OPTIONS]

Options:
  -t <DS_VERSION>     : Dev Spaces version to test, e.g. '3.0'. Required
  -n <NAMESPACE>      : Namespace to install everything into. Default: openshift-operators
  --checluster <PATH> : use CheCluster yaml defined at path instead of default. Optional
  --no-checluster     : Do not create CheCluster (use dsc later to create a custom one)
  --get-url           : Wait for Dev Spaces to install and print URL for dashboard (default)
  --no-get-url        : Don't wait for Dev Spaces to install and print URL for dashboard

  -kp, --kubepwd      : If not already connected to an OCP instance, use this kubeadmin password
  -os, --openshift    : If not already connected to an OCP instance, use this api.cluster:6443 url
                      : for https://console-openshift-console.apps.cluster-here.com instance,
                      : use api.cluster-here.com:6443
EOF
}

# Check we're logged into everything we need
preflight() {
  if [ -z "$DS_VERSION" ]; then
    errorf "Dev Spaces version is required (use '-t' parameter)"
    usage
    exit 1
  fi
  if [[ $KUBE_PWD ]] && [[ $OCP_URL ]]; then
    oc login ${OCP_URL} --username=kubeadmin --password=${KUBE_PWD}
  fi
  if ! oc whoami > /dev/null 2>&1; then
    errorf "Not logged into an OpenShift cluster"
    exit 1
  fi
  TOKENS=$(curl --negotiate -u : https://employee-token-manager.registry.redhat.com/v1/tokens -s)
  if [[ $TOKENS == *"no authorization context provided"* ]]; then 
    errorf "No registry token configured -- make sure you've run kinit and have a token set up according to"
    errorf "the 'Adding Brew Pull Secret' section in https://docs.engineering.redhat.com/display/CFC/Test"
    exit 1
  else
    BREW_TOKENS_NUM="$(echo "$TOKENS" | jq -r 'length')"
    if [[ "$BREW_TOKENS_NUM" == "0" ]]; then
      errorf "No registry token configured -- make sure you've run kinit and have a token set up according to"
      errorf "the 'Adding Brew Pull Secret' section in https://docs.engineering.redhat.com/display/CFC/Test"
      exit 1
    fi
  fi
  if [[ ! $(command -v htpasswd) ]] || [[ ! $(command -v bcrypt) ]]; then 
    errorf "Please install htpasswd and bcrypt to create users on the cluster"
    exit 1
  fi
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') DS_VERSION="$2"; shift 1;;
    '-n') NAMESPACE="$2"; shift 1;;
    '-kp'|'--kubepwd') KUBE_PWD="$2"; shift 1;;
    '-os'|'--openshift')   OCP_URL="$2"; shift 1;;
    '--checluster') CHECLUSTER_PATH="$2"; shift 1;;
    '--no-checluster') CREATE_CHECLUSTER="false";;
    '--get-url') GET_URL="true";;
    '--no-get-url') GET_URL="false";;
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


elapsed=0
inc=3
echo "Waiting for CheCluster CRs to be available in the cluster. Timeout is 3 minutes."
for _ in {1..60}; do
  echo -n '.'
  oc get crd checlusters.org.eclipse.che > /dev/null 2>&1 && break
  sleep $inc
  let elapsed=elapsed+inc
done
echo " $elapsed s elapsed"

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

# add admin user + user{1..5} to cluster
export HTPASSWD_FILE=/tmp/htpasswd
adminPwd="crw4ever!"
userPwd="openshift"
if [[ $(command -v htpasswd) ]] && [[ $(command -v bcrypt) ]]; then
  # using htpasswd + bcrypt hash (-B)
  for user in admin; do htpasswd -c   -bB $HTPASSWD_FILE "${user}" "${adminPwd}" 2>/dev/null; done
  for user in user{1..5}; do htpasswd -bB $HTPASSWD_FILE "${user}" "${userPwd}" 2>/dev/null; done
else
  errorf "Install htpasswd and bcrypt to create users"
fi
htpwd_encoded="$(cat $HTPASSWD_FILE | base64 -w 0)"
rm -f $HTPASSWD_FILE

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  creationTimestamp: null
  name: htpass-secret
  namespace: openshift-config
data: 
  htpasswd: ${htpwd_encoded}
EOF

oc patch oauths cluster --type merge -p '
spec:
  identityProviders:
    - name: htpasswd
      mappingMethod: claim
      type: HTPasswd
      htpasswd:
        fileData:
          name: htpass-secret
'

if [[ $GET_URL != "true" ]]; then
  echo "All done"
  exit 0
fi

echo "Waiting for Dev Spaces to install in the cluster. Timeout is 15 minutes."
elapsed=0
inc=5
for _ in {1..180}; do
  echo -n '.'
  STATUS=$(oc get checlusters devspaces -n "$NAMESPACE" -o json | jq -r '.status.cheClusterRunning')
  if [[ "$STATUS" == "Available" ]]; then
    break
  fi
  sleep $inc
  let elapsed=elapsed+inc
done
echo " $elapsed s elapsed"

# check if new user logins can be initialized
for user in user{1..5}; do oc login -u $user -p "${userPwd}" 2>&1 | grep "Login successful" -q || errorf "could not log in as $user"; done
for user in admin; do      oc login -u $user -p "${adminPwd}" 2>&1 | grep "Login successful" -q || errorf "could not log in as $user"; done

if [[ "$STATUS" != "Available" ]]; then
  errorf "Dev Spaces did not become available before timeout expired"
else
  echo "Dev Spaces is installed \o/"
  echo
fi

CHECLUSTER_JSON=$(oc get checlusters devspaces -n "$NAMESPACE" -o json)
# note due to redirection bug https://github.com/eclipse/che/issues/21416 append trailing slashes just in case
cat <<EOF
Dashboard URL.............. $(echo "$CHECLUSTER_JSON" | jq -r '.status.cheURL')/
Devfile registry URL....... $(echo "$CHECLUSTER_JSON" | jq -r '.status.devfileRegistryURL')/
Plugin registry URL........ $(echo "$CHECLUSTER_JSON" | jq -r '.status.pluginRegistryURL')/
Workspace base domain...... $(echo "$CHECLUSTER_JSON" | jq -r '.status.devworkspaceStatus.workspaceBaseDomain')
EOF
echo
