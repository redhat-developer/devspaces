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
NAMESPACE="openshift-devspaces"
OLM_NAMESPACE="openshift-operators"
# options for fetching GA or CI version of dsc for installation, or to use existing install (on path or not)
DSC_OPTION="" # commandline options include version, existing install path, or 'local' to search PATH
DSC="" # path to dsc binary, if being used
DELETE_BEFORE="false" # delete any existing installed Dev Spaces using dsc server:delete -y
CREATE_CHECLUSTER="true"
CREATE_USERS="false"
GET_URL="true"
DWO_VERSION="" # by default, install from latest release

# subscription channels
CHANNEL_DWO="fast"
CHANNEL_DS="stable"

# default ICSP to use to resolve unreleased images
# if using --fast or --quay flag, this will be changed to quay.io
# if using --brew flag, this will be changed to brew.registry.redhat.io
# if you want your own registry here, use --icsp flag to specify it
ICSP_FLAG=""

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
4. Create 5 dummy OpenShift users from user1 to user5
5. Create a CheCluster to install Dev Spaces

Usage: $0 [OPTIONS]

Options:
  -t <DS_VERSION>     : Dev Spaces version to test, e.g. '3.0'. Required
  -o <OLM_NAMESPACE>  : Namespace into which to install catalog source and operator. Default: $OLM_NAMESPACE
  -n <NAMESPACE>      : Namespace into which to install CheCluster + Dev Spaces. Default: $NAMESPACE
  --checluster <PATH> : use CheCluster yaml defined at path instead of default. Optional
  --no-checluster     : Do not create CheCluster (use dsc later to create a custom one)
  --create-users      : Add admin user + user{1..5} to cluster
  --no-create-users   : Do not add admin user + user{1..5} to cluster (default)
  --get-url           : Wait for Dev Spaces to install and print URL for dashboard (default)
  --no-get-url        : Don't wait for Dev Spaces to install and print URL for dashboard

  -kp, --kubepwd      : If not already connected to an OCP instance, use this kubeadmin password
  -os, --openshift    : If not already connected to an OCP instance, use this api.my-cluster-here.com:6443 URL
                      : For example, given https://console-openshift-console.apps.my-cluster-here.com instance,
                      : use 'my-cluster-here.com' (or longer format: 'api.my-cluster-here.com:6443')

  --dwo <VERSION>     : Dev Workspace Operator version to test, e.g. '0.15'. Optional
  --dwo-chan <CHANNEL>: Dev Workspace Operator channel to install; default: $CHANNEL_DWO (if --quay flag used, default: fast)
  --iib-dwo <IIB_URL> : Dev Workspace Operator IIB from which to install; default: computed from DWO version

  --ds-chan <CHANNEL> : Dev Spaces channel to install; default: $CHANNEL_DS (if --quay flag used, default: fast)
  --iib-ds <IIB_URL>  : Dev Spaces IIB from which to install; default: computed from DS version; options:
                      : * registry-proxy.engineering.redhat.com/rh-osbs/iib:987654 [RH internal],
                      : * brew.registry.redhat.io/rh-osbs/iib:987654 [RH public, auth required], or
                      : * quay.io/devspaces/iib:3.3-v4.11-987654-x86_64 [public], or 
                      : * quay.io/devspaces/iib:next-v4.10-ppc64le [public]
  --quay, --fast      : Install from quay.io/devspaces/iib:<DS_VERSION>-v4.yy-<OS_ARCH> (detected OCP version + arch) from fast channel
                      : Resolve images from quay.io using ImageContentSourcePolicy
  --brew              : Resolve images from brew.registry.redhat.io using ImageContentSourcePolicy
  --icsp <REGISTRY>   : Resolve images from specified registry URL using ImageContentSourcePolicy
  --dsc               : Optional. To install with dsc, use '--dsc 3.1.0-CI' or '--dsc 3.0.0-GA'
                      : Use '--dsc local' to search PATH for installed dsc, or use '--dsc /path/to/dsc/bin/'
  --delete-before     : Before installing with dsc, delete using server:delete -y. Will not delete namespaces.

EOF
}

# Check we're logged into everything we need
preflight() {
  # Download specified dsc version to /tmp and use that
  if [[ "$DSC_OPTION" =~ ^3\..*-(GA|CI)$ ]]; then 
    DSC_VER="${DSC_OPTION}"
    rm -fr /tmp/dsc-${DSC_VER}/; mkdir -p /tmp/dsc-${DSC_VER}/
    pushd /tmp/dsc-${DSC_VER}/ >/dev/null
      asset_dir="${DSC_VER}-dsc-assets"
      # old folder format
      # echo "curl https://github.com/redhat-developer/devspaces-chectl/releases/download/${asset_dir}/devspaces-${DSC_VER/-CI/}-quay-dsc-linux-x64.tar.gz ... "
      if [[ $(curl -sSIk https://github.com/redhat-developer/devspaces-chectl/releases/download/${asset_dir}/devspaces-${DSC_VER/-CI/}-quay-dsc-linux-x64.tar.gz | grep HTTP/ | grep 404) ]]; then 
        # https://github.com/redhat-developer/devspaces-chectl/releases/download/2.15.4-crwctl-assets/codeready-workspaces-2.15.4-GA-quay-crwctl-linux-x64.tar.gz
        asset_dir="${asset_dir/-GA/}"
        # https://github.com/redhat-developer/devspaces-chectl/releases/download/2.15.4-crwctl-CI-assets/codeready-workspaces-2.15.4-CI-quay-crwctl-linux-x64.tar.gz
        asset_dir="${asset_dir/CI-dsc/dsc-CI}"
      fi
      # echo "curl https://github.com/redhat-developer/devspaces-chectl/releases/download/${asset_dir}/devspaces-${DSC_VER/-CI/}-quay-dsc-linux-x64.tar.gz ... "
      if [[ ! $(curl -sSIk https://github.com/redhat-developer/devspaces-chectl/releases/download/${asset_dir}/devspaces-${DSC_VER/-CI/}-quay-dsc-linux-x64.tar.gz | grep HTTP/ | grep 404) ]]; then 
        curl -sSLko- https://github.com/redhat-developer/devspaces-chectl/releases/download/${asset_dir}/devspaces-${DSC_VER/-CI/}-quay-dsc-linux-x64.tar.gz | tar xz || true
        DSC=/tmp/dsc-${DSC_VER}/dsc/bin/dsc
        echo "dsc installed to ${DSC}"
      else
        echo "Could not download dsc from https://github.com/redhat-developer/devspaces-chectl/releases/download/${asset_dir}/devspaces-${DSC_VER/-CI/}-quay-dsc-linux-x64.tar.gz !"
        if [[ ! $(curl -sSIk https://github.com/redhat-developer/devspaces-chectl/releases/download/${asset_dir}/devspaces-${DSC_VER}-quay-dsc-linux-x64.tar.gz | grep HTTP/ | grep 404) ]]; then 
          curl -sSLko- https://github.com/redhat-developer/devspaces-chectl/releases/download/${asset_dir}/devspaces-${DSC_VER}-quay-dsc-linux-x64.tar.gz | tar xz || true
          DSC=/tmp/dsc-${DSC_VER}/dsc/bin/dsc
          echo "dsc installed to ${DSC}"
        else
          errorf "Could not download dsc from https://github.com/redhat-developer/devspaces-chectl/releases/download/${asset_dir}/devspaces-${DSC_VER}-quay-dsc-linux-x64.tar.gz !"
          if [[ -d /tmp/dsc-${DSC_VER} ]]; then popd >/dev/null; rm -fr /tmp/dsc-${DSC_VER}; fi
          exit 2
        fi
      fi
    popd >/dev/null
  # Or, use dsc in ${DSC_OPTION}/dsc; error if not found
  elif [[ ! -z $DSC_OPTION ]] && [[ $DSC_OPTION != "local" ]]; then 
    if [[ ! -d $DSC_OPTION ]] || [[ ! $(command -v ${DSC_OPTION}/dsc) ]]; then 
      errorf "Can't find dsc in folder $DSC_OPTION. Please install dsc to your PATH, or use '--dsc /path/to/dsc/bin/'"
      exit 1
    fi
    DSC="$(command -v ${DSC_OPTION}/dsc)"
  fi

  if [[ ! $(command -v htpasswd) ]] || [[ ! $(command -v bcrypt) ]]; then 
    errorf "Please install htpasswd and bcrypt to create users on the cluster"
    exit 1
  fi

  if [ -z "$DS_VERSION" ]; then
    errorf "Dev Spaces version is required (use '-t' parameter)"
    usage
    exit 1
  fi
  if [[ $KUBE_PWD ]] && [[ $OCP_URL ]]; then
    # check OCP_URL for "api." prefix and ":portnum" suffix; if missing, prepend/append defaults
    if [[ $OCP_URL == ${OCP_URL%:*} ]]; then OCP_URL="${OCP_URL}:6443"; fi
    if [[ $OCP_URL == ${OCP_URL#api.} ]]; then OCP_URL="api.${OCP_URL}"; fi
    oc login ${OCP_URL} --username=kubeadmin --password=${KUBE_PWD}
  fi
  if ! oc whoami > /dev/null 2>&1; then
    errorf "Not logged into an OpenShift cluster"
    exit 1
  fi
  if [[ "${ICSP_FLAG}" == "--icsp brew.registry.redhat.io" ]]; then 
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
  fi
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') DS_VERSION="$2"; shift 1;;
    '--dwo') DWO_VERSION="$2"; shift 1;;
    '--dwo-chan') CHANNEL_DWO="$2"; shift 1;;
    '--ds-chan') CHANNEL_DS="$2"; shift 1;;
    '-n') NAMESPACE="$2"; shift 1;;
    '-o') OLM_NAMESPACE="$2"; shift 1;;
    '-kp'|'--kubepwd') KUBE_PWD="$2"; shift 1;;
    '-os'|'--openshift')   OCP_URL="$2"; shift 1;;
    '--checluster') CHECLUSTER_PATH="$2"; shift 1;;
    '--no-checluster') CREATE_CHECLUSTER="false";;
    '--create-users') CREATE_USERS="true";;
    '--no-create-users') CREATE_USERS="false";;
    '--dsc') DSC_OPTION="$2";
      if [[ $DSC_OPTION == "" ]] || [[ $DSC_OPTION == "local" ]]; then # can omit "local" and still check PATH for dsc binary
        if [[ ! $(command -v dsc) ]]; then 
          errorf "Can't find dsc on your PATH. Please install dsc or use '--dsc /path/to/dsc/bin/'"
          exit 1
        else 
          DSC=$(command -v dsc)
        fi
      fi; shift 1;;
    '--iib-dwo') IIB_DWO="$2"; shift 1;;
    '--iib-ds') IIB_DS="$2"; shift 1;;
    '--quay'|'--fast') IIB_DS="quay.io/devspaces/iib"; CHANNEL_DS="fast"; CHANNEL_DWO="fast"; ICSP_FLAG="--icsp quay.io";;
    '--brew') ICSP_FLAG="--icsp brew.registry.redhat.io";;
    '--icsp') ICSP_FLAG="--icsp $2"; shift 1;;
    '--delete-before') DELETE_BEFORE="true";;
    '--get-url') GET_URL="true";;
    '--no-get-url') GET_URL="false";;
    '-h'|'--help') usage; exit 0;;
  esac
  shift 1
done

preflight

# detect openshift server version and arch; for amd, use x86_64; for others, trim linux/ prefix
OPENSHIFT_VER=$(oc version -o json | jq -r '.openshiftVersion | scan("^[0-9].[0-9]+")')
OPENSHIFT_ARCH=$(oc version -o json | jq -r '.serverVersion.platform' | sed -r -e "s#linux/amd64#x86_64#" -e "s#linux/##")
echo "Detected OpenShift: v$OPENSHIFT_VER $OPENSHIFT_ARCH"

if [[ $DWO_VERSION ]]; then
  if [[ ! $IIB_DWO ]] && [[ $DWO_VERSION ]]; then # compute the latest IIB for the DWO version passed in
    IIB_DWO=$("$SCRIPT_DIR"/getLatestIIBs.sh --dwo -t "$DWO_VERSION" -o "$OPENSHIFT_VER" -q)
    if [[ ! $ICSP_FLAG ]]; then ICSP_FLAG="--icsp brew.registry.redhat.io"; fi
    if [[ $IIB_DWO ]]; then
      echo "[INFO] Found latest Dev Workspace Operator IIB $IIB_DWO - installing from $CHANNEL_DWO channel..."
    else
      echo "[ERROR] could not find Dev Workspace Operator IIB for DWO $DWO_VERSION -- use '--iib-dwo' flag to specify an IIB URL from which to install CatalogSource"
      exit 1
    fi
  elif [[ $IIB_DWO ]]; then
    echo "[INFO] Requested Dev Workspace Operator IIB $IIB_DWO - installing from $CHANNEL_DWO channel..."
  fi
fi
if [[ $IIB_DWO ]]; then
  # catalog is installed as "iib-testingdevworkspace-operator"
  "$SCRIPT_DIR"/installCatalogSourceFromIIB.sh \
    --iib "$IIB_DWO" \
    --install-operator "devworkspace-operator" \
    --channel "$CHANNEL_DWO" \
    --namespace "$OLM_NAMESPACE" ${ICSP_FLAG}
fi

if [[ ! $IIB_DS ]]; then
  IIB_DS=$("$SCRIPT_DIR"/getLatestIIBs.sh --ds -t "$DS_VERSION"  -o "$OPENSHIFT_VER" -q)
  if [[ ! $ICSP_FLAG ]]; then ICSP_FLAG="--icsp brew.registry.redhat.io"; fi
  if [[ $IIB_DS ]]; then 
    echo "[INFO] Found latest Dev Spaces IIB $IIB_DS - installing from $CHANNEL_DS channel..."
  else
    echo "[ERROR] could not find Dev Spaces IIB -- use '--iib-ds' flag to specify an IIB URL from which to install CatalogSource"
    exit 1
  fi
else
  if [[ $IIB_DS == "quay.io/devspaces/iib" ]]; then 
    IIB_DS="${IIB_DS}:${DS_VERSION}-v${OPENSHIFT_VER}-${OPENSHIFT_ARCH}"
  fi
  echo "[INFO] Requested Dev Spaces IIB $IIB_DS - installing from $CHANNEL_DS channel..."
fi

# catalog is installed as "iib-testingdevspaces"
"$SCRIPT_DIR"/installCatalogSourceFromIIB.sh \
  --iib "$IIB_DS" \
  --install-operator "devspaces" \
  --channel "$CHANNEL_DS" \
  --namespace "$OLM_NAMESPACE" ${ICSP_FLAG}

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

if [[ "$CREATE_CHECLUSTER" == "false" ]]; then
  echo "Not creating CheCluster -- all done"
  exit 0
fi

# add admin user + user{1..5} to cluster
createUsers() {
  if [[ $CREATE_USERS == "true" ]]; then
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
  fi
}

if [[ $DELETE_BEFORE != "true" ]] || [[ ! $(command -v ${DSC}) ]]; then 
  createUsers
fi

if [[ $(command -v ${DSC}) ]]; then # use dsc
  if [[ $DELETE_BEFORE == "true" ]]; then 
    echo
    echo "Using dsc from ${DSC}"
    ${DSC} server:delete -y -n "${NAMESPACE}" --listr-renderer=verbose --telemetry=off
    echo -n "Sleeping for 30s "
    for _ in {1..6}; do
      echo -n '.'
      sleep 5s
    done
  fi
  echo
  echo "Using dsc from ${DSC}"
  ${DSC} server:deploy \
    --catalog-source-namespace=openshift-operators \
    --catalog-source-name=iib-testingdevspaces --olm-channel=stable \
    --package-manifest-name="devspaces" -n "${NAMESPACE}" \
    --listr-renderer=verbose --telemetry=off

  if [[ $DELETE_BEFORE == "true" ]]; then 
    createUsers
  fi
else
  # TODO: add support for custom patch YAML
  if [ -z "$CHECLUSTER_PATH" ]; then
    oc create namespace $NAMESPACE || true
    cat <<EOF | oc apply -f -
apiVersion: org.eclipse.che/v2
kind: CheCluster
metadata:
  name: devspaces
  namespace: $NAMESPACE
spec:
  components:
    cheServer:
      debug: false
      logLevel: INFO
    database:
      credentialsSecretName: postgres-credentials
      externalDb: false
      postgresDb: dbche
      postgresHostName: postgres
      postgresPort: '5432'
      pvc:
        claimSize: 1Gi
    metrics:
      enable: true
  containerRegistry: {}
  devEnvironments:
    secondsOfRunBeforeIdling: -1
    defaultNamespace:
      template: <username>-devspaces
    secondsOfInactivityBeforeIdling: 1800
    storage:
      pvcStrategy: common
  networking: {}
EOF
  else
    oc apply -f "$CHECLUSTER_PATH"
  fi

cat <<EOF | oc apply -f - 
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: devspaces-operator
  namespace: ${NAMESPACE}
EOF
fi

if [[ $GET_URL != "true" ]]; then
  echo "All done"
  exit 0
fi

echo "Waiting for Dev Spaces to install in the cluster. Timeout is 15 minutes."
# .status = 
# {
#   "chePhase": "Active",
#   "cheURL": "https://devspaces.apps.ci-ln-13tgpm2-72292.origin-ci-int-gce.dev.rhcloud.com",
#   "cheVersion": "3.1.0",
#   "devfileRegistryURL": "https://devspaces.apps.ci-ln-13tgpm2-72292.origin-ci-int-gce.dev.rhcloud.com/devfile-registry",
#   "gatewayPhase": "Established",
#   "pluginRegistryURL": "https://devspaces.apps.ci-ln-13tgpm2-72292.origin-ci-int-gce.dev.rhcloud.com/plugin-registry/v3",
#   "postgresVersion": "13.7",
#   "workspaceBaseDomain": "apps.ci-ln-13tgpm2-72292.origin-ci-int-gce.dev.rhcloud.com"
# }
elapsed=0
inc=5
for _ in {1..180}; do
  echo -n '.'
  STATUS=$(oc get checlusters devspaces -n "$NAMESPACE" -o json | jq -r '.status.gatewayPhase')
  if [[ "$STATUS" == *"Established"* ]]; then
    break
  fi
  sleep $inc
  let elapsed=elapsed+inc
done
echo " $elapsed s elapsed"

if [[ $CREATE_USERS == "true" ]]; then
  # check if new user logins can be initialized
  for user in user{1..5}; do oc login -u $user -p "${userPwd}" 2>&1 | grep "Login successful" -q || errorf "could not log in as $user"; done
  for user in admin; do      oc login -u $user -p "${adminPwd}" 2>&1 | grep "Login successful" -q || errorf "could not log in as $user"; done
fi

if [[ "$STATUS" != "Established" ]]; then
  errorf "Dev Spaces did not become available before timeout expired"
else
  echo "Dev Spaces is installed \o/"
  echo
fi

# patch CheCluster so we can run up to 30 workspaces in parallel (instead of default 1)
echo -n "Allow up to 30 concurrent workspace starts... " && \
oc patch checluster/devspaces -n "${NAMESPACE}" --type='merge' -p '{"spec":{"components":{"devWorkspace":{"runningLimit":"30"}}}}'

CHECLUSTER_JSON=$(oc get checlusters devspaces -n "$NAMESPACE" -o json)
# note due to redirection bug https://github.com/eclipse/che/issues/21416 append trailing slashes just in case
cat <<EOF
Dashboard URL.............. $(echo "$CHECLUSTER_JSON" | jq -r '.status.cheURL')/
Devfile registry URL....... $(echo "$CHECLUSTER_JSON" | jq -r '.status.devfileRegistryURL')/
Plugin registry URL........ $(echo "$CHECLUSTER_JSON" | jq -r '.status.pluginRegistryURL')/
Workspace base domain...... $(echo "$CHECLUSTER_JSON" | jq -r '.status.workspaceBaseDomain')
EOF
echo
