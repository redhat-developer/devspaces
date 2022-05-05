#!/bin/bash
#
# Copyright (c) 2018-2022 Red Hat, Inc.
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
Collect relevant operators from an IIB image and build a new index image to include only those operators.
Depends on podman and opm v1.19.5 or higher

Usage: $0 [args...]

Arguments:
  --iib <IMAGE>   : IIB image to pull operators from. Required.
  --tag <TAG>     : Repo + tag to use for new index image.
  --include-crw   : Include CodeReady Workspaces in new index.
  --push          : Push new index image remotely.
  --no-temp-dir   : Work in current directory instead of a temporary one.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--iib') IIB_IMAGE="$2"; shift 1;;
    '--tag') TAG="$2"; shift 1;;
    '--include-crw') INCLUDE_CRW="true";;
    '--push') PUSH="true";;
    '--no-temp-dir') USE_TMP="false";;
    '-h'|'--help') usage; exit 0;;
    *) echo "Unknown parameter used: $1."; usage; exit 1;;
  esac
  shift 1
done

if [ -z $IIB_IMAGE ]; then
  echo "IIB image required"
  usage
  exit 1
fi

if [ -z $TAG ]; then
  echo "Image must be specified with --tag"
  usage
  exit 1
fi

if [ "$USE_TMP" != "false" ]; then
  TEMP_DIR=$(mktemp -d)
  echo "Working in $TEMP_DIR"
  cd $TEMP_DIR
fi

if [ ! -f ./render.json ]; then
  echo "Rendering $IIB_IMAGE. This can take awhile."
  opm render "$IIB_IMAGE" > render.json
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

podman build -t $TAG -f olm-catalog.Dockerfile .

if [[ "$PUSH" == "true" ]]; then
  podman push $TAG
fi
echo "Index image $TAG is built and ready for use"
