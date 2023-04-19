#!/bin/bash
#
# Copyright (c) 2022-2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Utility script build a catalog image from bundle, channel, and package files rendered
# by filterIIB.sh. The built catalog contains only operators in files and is
# thus smaller in size.
# OPM from 4.12 (>v1.26.3 upstream version) is required to run buildCatalog.sh (CRW-4192, OCPBUGS-11841)
#

usage() {
  cat <<EOF
Build an IIB OLM catalog from a set of files defining the operators (bundles, channels, packages) that
should be included, resulting in a smaller OLM catalog that contains only those operators. This script
is intended for use in conjunction with filterIIB.sh

Requires:
* jq 1.6+, podman 2.0+, glibc 2.28+
* opm v1.26.3+ (see https://docs.openshift.com/container-platform/4.12/cli_reference/opm/cli-opm-install.html#cli-opm-install )

Usage: $0 [OPTIONS]

Options:
  -t, --image <target_index> : Target registry, org, index image and tag to create. Generated if not provided.
  -o, --ocp-ver <version>    : OCP version to target
  -p, --push                 : Push new index image to <target_index> on remote server.
  --dir <directory>          : Build catalog from <directory>/olm-catalog instead of ./olm-catalog
  -v, --verbose              : Verbose output: include additional information
  -h, --help                 : Show this help

Example:
  $0 -t quay.io/devspaces/iib:226720

EOF
}

VERBOSE=0
WORKING_DIR='./'

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t'|'--image') targetIndexImage="$2"; shift 1;;
    '-o'|'--ocp-ver') OCP_VER="$2"; shift 1;;
    '-p'|'--push') PUSH="true";;
    '--dir') WORKING_DIR="$2"; shift 1;;
    '-v'|'--verbose') VERBOSE=1;;
    '-h'|'--help') usage;;
    *) echo "Unknown parameter used: $1."; usage; exit 1;;
  esac
  shift 1
done

# shellcheck disable=SC2086
if [ -z $OCP_VER ]; then echo "OCP ('-o', '--ocp-ver') version option is required"; exit 1; fi

# install opm if not installed from https://mirror.openshift.com/pub/openshift-v4/$(uname -m)/clients/ocp/latest-4.12/opm-linux.tar.gz
if [[ ! -x /usr/local/bin/opm ]] && [[ ! -x ${HOME}/.local/bin/opm ]]; then 
    pushd /tmp >/dev/null || exit
    echo "[INFO] Installing latest opm from https://mirror.openshift.com/pub/openshift-v4/$(uname -m)/clients/ocp/latest-4.12/opm-linux.tar.gz ..."
    curl -sSLo- "https://mirror.openshift.com/pub/openshift-v4/$(uname -m)/clients/ocp/latest-4.12/opm-linux.tar.gz" | tar xz; chmod 755 opm
    sudo cp opm /usr/local/bin/ || cp opm "${HOME}"/.local/bin/
    sudo chmod 755 /usr/local/bin/opm || chmod 755 "${HOME}"/.local/bin/opm
    if [[ ! -x /usr/local/bin/opm ]] && [[ ! -x "${HOME}"/.local/bin/opm ]]; then 
        echo "[ERROR] Could not install opm v1.26.3 or higher (see https://docs.openshift.com/container-platform/4.12/cli_reference/opm/cli-opm-install.html#cli-opm-install )";
        exit 1
    fi
    popd >/dev/null || exit
fi

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then echo "[ERROR] podman is not installed. Aborting."; echo; usage; exit 1; fi
command -v jq >/dev/null 2>&1     || which jq >/dev/null 2>&1     || { echo "jq is not installed. Aborting."; exit 1; }

# shellcheck disable=SC2086
if [ -z $targetIndexImage ]; then
  targetIndexImage="quay.io/devspaces/$(date +%s)"
  echo "No target image specified: using ${targetIndexImage}"
fi

pushd "$WORKING_DIR" > /dev/null || exit
trap 'popd > /dev/null' EXIT

if [ ! -d ./olm-catalog ]; then
  echo "Specified directory $(pwd) does not contain files for an OLM catalog. Aborting"
  exit 1
fi

if [ -f ./olm-catalog.Dockerfile ]; then rm -f ./olm-catalog.Dockerfile; fi
# shellcheck disable=SC2086
$PODMAN rmi --ignore --force $targetIndexImage >/dev/null 2>&1 || true

# new way for OCP 4.12+
# CRW-4192, OCPBUGS-11841 - update to 4.12
OSE_VER="v4.12" 
cat <<EOF > olm-catalog.Dockerfile
# The base image is expected to contain
# /bin/opm (with a serve subcommand) and /bin/grpc_health_probe
FROM registry.redhat.io/openshift4/ose-operator-registry:${OSE_VER}

# Configure the entrypoint and command
ENTRYPOINT ["/bin/opm"]
CMD ["serve", "/configs"]

# Copy declarative config root into image at /configs
ADD olm-catalog /configs

# Set DC-specific label for the location of the DC root directory
# in the image
LABEL operators.operatorframework.io.index.configs.v1=/configs
EOF
if [[ $VERBOSE -eq 1 ]]; then
  echo "Generated dockerfile from ose-operator-registry:${OSE_VER} for OCP $OCP_VER:"
  cat olm-catalog.Dockerfile
fi

validation=$(opm validate olm-catalog && echo $?)
# shellcheck disable=SC2086
if [[ $validation -ne 0 ]]; then echo "[ERROR] 'opm validate olm-catalog' returned exit code: $validation"; exit $validation; fi

# shellcheck disable=SC2086
$PODMAN build -t $targetIndexImage -f olm-catalog.Dockerfile . -q
# shellcheck disable=SC2086
if [[ "$PUSH" == "true" ]]; then $PODMAN push $targetIndexImage -q; fi

if [[ $VERBOSE -eq 1 ]]; then
  echo "Index image built and ready for use"
fi
echo "[IMG] $targetIndexImage"

# cleanup source IIB image; don't delete the target image as we might need to copy it again to a new tag
# $PODMAN rmi $sourceIndexImage
