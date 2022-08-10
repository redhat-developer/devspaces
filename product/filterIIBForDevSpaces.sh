#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Utility script to pull the Dev Spaces, Web Terminal, DevWorkspace (and optionally CodeReady Workspaces) operators
# from an IIB image and build an index image that contains only those images.
# OPM 4.10 is required to run filterIIBForDevSpaces.sh
#

usage() {
  cat <<EOF
Collect Dev Spaces, Web Terminal, DevWorkspace operators from an IIB image into a new, smaller IIB image.
Optionally publish the resulting image to Quay.

Requires:
* jq 1.6+, podman 2.0+, glibc 2.28+
* opm v1.19.5+ (see https://docs.openshift.com/container-platform/4.10/cli_reference/opm/cli-opm-install.html#cli-opm-install )

Usage: $0 [OPTIONS]

Options:
  -s, --iib <source_index>   : Source registry, org, index image and tag from which to pull operators. Required.
  -t, --image <target_index> : Target registry, org, index image and tag to create. Generated if not provided.
  -p, --push                 : Push new index image to <target_index> on remote server.
  --include-crw              : Include CodeReady Workspaces in new index. Useful for testing migration from 2.15 -> 3.x.
  --no-temp-dir              : Work in current directory instead of a temporary one.
  -v                         : Verbose output: include additional information
  -h, --help                 : Show this help

Example:
  $0 -s registry-proxy.engineering.redhat.com/rh-osbs/iib:226720

EOF
}

VERBOSE=0
LIST_COPIES_ONLY=0 # only list the copied images, nothing more

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-s'|'--iib') sourceIndexImage="$2"; shift 1;;
    '-t'|'--image') targetIndexImage="$2"; shift 1;;
    '-p'|'--push') PUSH="true";;
    '--include-crw') INCLUDE_CRW="true";;
    '--no-temp-dir') USE_TMP="false";;
    '-v')                 VERBOSE=1; LIST_COPIES_ONLY=0;;
    '--list-copies-only') LIST_COPIES_ONLY=1; VERBOSE=0;;
    '-h'|'--help') usage;;
    *) echo "Unknown parameter used: $1."; usage; exit 1;;
  esac
  shift 1
done

# install opm if not installed from https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.11/opm-linux.tar.gz
# note, this won't run on s390x or ppc64le, only on amd64
if [[ ! -x /usr/local/bin/opm ]] && [[ ! -x ${HOME}/.local/bin/opm ]]; then 
    pushd /tmp >/dev/null
    echo "[INFO] Installing latest opm from https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.11/opm-linux.tar.gz ..."
    curl -sSLo- https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.11/opm-linux.tar.gz | tar xz; chmod 755 opm
    sudo cp opm /usr/local/bin/ || cp opm ${HOME}/.local/bin/
    sudo chmod 755 /usr/local/bin/opm || chmod 755 ${HOME}/.local/bin/opm
    if [[ ! -x /usr/local/bin/opm ]] && [[ ! -x ${HOME}/.local/bin/opm ]]; then 
        echo "[ERROR] Could not install opm v1.19.5 or higher (see https://docs.openshift.com/container-platform/4.10/cli_reference/opm/cli-opm-install.html#cli-opm-install )";
        exit 1
    fi
    popd >/dev/null
fi

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then echo "[ERROR] podman is not installed. Aborting."; echo; usage; exit 1; fi
command -v jq >/dev/null 2>&1     || which jq >/dev/null 2>&1     || { echo "jq is not installed. Aborting."; exit 1; }

if [ -z $sourceIndexImage ]; then echo "IIB image required"; echo; usage; exit 1; fi

if [ -z $targetIndexImage ]; then 
  targetIndexImage="quay.io/devspaces/${sourceIndexImage##*/}"
  if [[ $LIST_COPIES_ONLY -eq 0 ]] || [[ $VERBOSE -eq 1 ]]; then
    echo "No target image specified: using ${targetIndexImage}"
  fi
fi

if [ "$USE_TMP" != "false" ]; then
  TEMP_DIR=$(mktemp -d)
  if [[ $LIST_COPIES_ONLY -eq 0 ]] || [[ $VERBOSE -eq 1 ]]; then
    echo -n "Working in $TEMP_DIR. "
  fi
  pushd $TEMP_DIR >/dev/null
fi

if [ -f ./render.json ]; then rm -f ./render.json; fi
if [[ $LIST_COPIES_ONLY -eq 0 ]] || [[ $VERBOSE -eq 1 ]]; then
  echo "Rendering $sourceIndexImage. This will take several minutes."
  time opm render "$sourceIndexImage" > render.json
else
  opm render "$sourceIndexImage" > render.json
fi
# ls -la render.json

rm -rf olm-catalog
mkdir -p olm-catalog/devspaces

# Grab devspaces
jq 'select(.schema == "olm.package") | select(.name == "devspaces")' render.json > olm-catalog/devspaces/package.json
jq 'select(.package == "devspaces") | select(.schema == "olm.channel")' render.json > olm-catalog/devspaces/channel.json
for bundle in $(jq -r 'select(.package == "devspaces") | select(.schema == "olm.bundle") | .name' render.json); do
  jq --arg bundle $bundle 'select(.name == $bundle) | select(.schema == "olm.bundle")' render.json > "olm-catalog/devspaces/$bundle.bundle.json"
done

# Grab CRW if needed
if [[ "$INCLUDE_CRW" == "true" ]]; then
  mkdir -p olm-catalog/codeready-workspaces
  jq 'select(.schema == "olm.package") | select(.name == "codeready-workspaces")' render.json > olm-catalog/codeready-workspaces/package.json
  jq 'select(.package == "codeready-workspaces") | select(.schema == "olm.channel")' render.json > olm-catalog/codeready-workspaces/channel.json
  for bundle in $(jq -r 'select(.package == "codeready-workspaces") | select(.schema == "olm.bundle") | .name' render.json); do
    jq --arg bundle $bundle 'select(.name == $bundle) | select(.schema == "olm.bundle")' render.json > "olm-catalog/codeready-workspaces/$bundle.bundle.json"
  done
fi

# Grab Web Terminal
mkdir -p olm-catalog/web-terminal
jq 'select(.schema == "olm.package") | select(.name == "web-terminal")' render.json > olm-catalog/web-terminal/package.json
jq 'select(.package == "web-terminal") | select(.schema == "olm.channel")' render.json > olm-catalog/web-terminal/channel.json
for bundle in $(jq -r 'select(.package == "web-terminal") | select(.schema == "olm.bundle") | .name' render.json); do
  jq --arg bundle $bundle 'select(.name == $bundle) | select(.schema == "olm.bundle")' render.json > "olm-catalog/web-terminal/$bundle.bundle.json"
done

# Grab DevWorkspace Operator
mkdir -p olm-catalog/devworkspace-operator
jq 'select(.schema == "olm.package") | select(.name == "devworkspace-operator")' render.json > olm-catalog/devworkspace-operator/package.json
jq 'select(.package == "devworkspace-operator") | select(.schema == "olm.channel")' render.json > olm-catalog/devworkspace-operator/channel.json
for bundle in $(jq -r 'select(.package == "devworkspace-operator") | select(.schema == "olm.bundle") | .name' render.json); do
  jq --arg bundle $bundle 'select(.name == $bundle) | select(.schema == "olm.bundle")' render.json > "olm-catalog/devworkspace-operator/$bundle.bundle.json"
done

if [ -f ./olm-catalog.Dockerfile ]; then rm -f ./olm-catalog.Dockerfile; fi
$PODMAN rmi --ignore --force $targetIndexImage >/dev/null 2>&1 || true
opm alpha generate dockerfile ./olm-catalog
$PODMAN build -t $targetIndexImage -f olm-catalog.Dockerfile . -q
if [[ "$PUSH" == "true" ]]; then $PODMAN push $targetIndexImage -q; fi

if [[ $LIST_COPIES_ONLY -eq 0 ]] || [[ $VERBOSE -eq 1 ]]; then
  echo "Index image built and ready for use"
fi
echo "[IMG] $targetIndexImage"

if [ "$USE_TMP" != "false" ]; then
  popd >/dev/null
  rm -fr $TEMP_DIR
fi

# cleanup source IIB image; don't delete the target image as we might need to copy it again to a new tag
# $PODMAN rmi $sourceIndexImage
