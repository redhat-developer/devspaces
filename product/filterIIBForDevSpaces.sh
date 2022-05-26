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
#

set -e

usage() {
  cat <<EOF
Collect relevant operators from an IIB image into a new, smaller IIB image.

Requires:
* podman version 1.9.3+ (version 2.0+ recommended)
* glibc version 2.28+
* opm v1.19.5 or higher (see https://docs.openshift.com/container-platform/4.10/cli_reference/opm/cli-opm-install.html#cli-opm-install )

Usage: $0 [OPTIONS]

Options:
  -s, --iib <source_index>   : Source registry, org, index image and tag from which to pull operators. Required.
  -t, --image <target_index> : Target registry, org, index image and tag to create. Generated if not provided.
  -p, --push                 : Push new index image to <target_index> on remote server.
  --include-crw              : Include CodeReady Workspaces in new index. Useful for testing migration from 2.15 -> 3.x.
  --no-temp-dir              : Work in current directory instead of a temporary one.

Example:
  $0 -s registry-proxy.engineering.redhat.com/rh-osbs/iib:226720

EOF
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-s'|'--iib') sourceIndexImage="$2"; shift 1;;
    '-t'|'--image') targetIndexImage="$2"; shift 1;;
    '-p'|'--push') PUSH="true";;
    '--include-crw') INCLUDE_CRW="true";;
    '--no-temp-dir') USE_TMP="false";;
    '-h'|'--help') usage; exit 0;;
    *) echo "Unknown parameter used: $1."; usage; exit 1;;
  esac
  shift 1
done

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then echo "[ERROR] podman is not installed. Aborting."; echo; usage; exit 1; fi

if [ -z $sourceIndexImage ]; then echo "IIB image required"; echo; usage; exit 1; fi

if [ -z $targetIndexImage ]; then 
  targetIndexImage="quay.io/devspaces/${sourceIndexImage##*/}"
  echo "No target image specified: using ${targetIndexImage}"
fi

if [ "$USE_TMP" != "false" ]; then
  TEMP_DIR=$(mktemp -d)
  echo "Working in $TEMP_DIR"
  cd $TEMP_DIR
fi

if [ ! -f ./render.json ]; then
  echo "Rendering $sourceIndexImage. This will take several minutes."
  time opm render "$sourceIndexImage" > render.json
fi

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

if [ -f ./olm-catalog.Dockerfile ]; then
  rm -f ./olm-catalog.Dockerfile
fi
opm alpha generate dockerfile ./olm-catalog

$PODMAN build -t $targetIndexImage -f olm-catalog.Dockerfile .

if [[ "$PUSH" == "true" ]]; then
  $PODMAN push $targetIndexImage
fi
echo "Index image $targetIndexImage is built and ready for use"
