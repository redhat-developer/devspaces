#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to get latest DWO IIB, compute the operator-bundle included in it, 
# compute the payload images (operator and project clone), and copy all three
# to quay so that pre-released CI images can more easily be installed along with
# Dev Spaces

# must be logged in to the source and target registries to read from and copy to

VERBOSE=0
RED='\033[0;31m'
NC='\033[0m'

errorf() {
  echo -e "${RED}Error: $1${NC}"
}

usage() {
  echo "
This script will attempt to:
* compute the latest DWO IIB (requires RH internal access to https://datagrepper.engineering.redhat.com), 
  * compute the operator-bundle + tag included in the index, 
  * if unsuccessful, compute the latest DWO operator-bundle image in registry-proxy.engineering.redhat.com/rh-osbs/
* compute the payload images (operator and project clone), and 
* copy all three to quay so that pre-released CI images can more easily be installed 

Usage: 
  $0 -t PROD_VER [OPTIONS]

Options:
  --latest, --next    In addition to creating a :PROD_VER tag, also create a :latest or :next tag (cannot be both)
  -v                  Verbose output
"
}

latestNext=""
PUSHTOQUAYFORCEFLAG=""
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') PROD_VER="$2"; shift 1;;
    '--latest') latestNext="latest";;
    '--next') latestNext="next";;
    '--force') PUSHTOQUAYFORCEFLAG="--force";;
    '-v') VERBOSE=1;;
    '-h') usage;;
  esac
  shift 1
done

if [[ ! $PROD_VER ]]; then usage; exit 1; fi

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)

# 1. use getLatestImageTags.sh to get latest bundle in an IIB - return: operator-bundle:0.16-5 
bundle=$(${SCRIPT_DIR}/getLatestImageTags.sh --osbs -c devworkspace-operator-bundle --tag "${PROD_VER}")
if [[ ! $bundle ]]; then
    errorf "Could not compute latest bundle! "
    exit 2
fi
if [[ $VERBOSE -eq 1 ]]; then echo "Got bundle: $bundle"; fi

# 2. for that bundle, get payload images from the CSV
	# brew.registry.redhat.io/rh-osbs/devworkspace-project-clone:0.16-3
	# brew.registry.redhat.io/rh-osbs/devworkspace-operator:0.16-3
operands=$(${SCRIPT_DIR}/checkImagesInCSV.sh ${bundle} \
    --brew -i "devworkspace" -q | tr "\n" " ")
if [[ $VERBOSE -eq 1 ]]; then echo "Got operands: $operands"; fi

# 3. copy these three images to quay, renaming on the fly (adding the -rhel8 back into the names)
	# devworkspace-operator-bundle == devworkspace-operator-bundle
	# devworkspace-project-clone -> devworkspace-project-clone-rhel8
	# devworkspace-operator -> devworkspace-rhel8-operator
# add -v for more verbose output
if [[ $VERBOSE -eq 1 ]]; then 
    if [[ $latestNext ]]; then
        echo "Pushing to quay (including tags: ${PROD_VER} + ${latestNext})..."
    else
        echo "Pushing to quay (including tag: ${PROD_VER})..."
    fi
    ${SCRIPT_DIR}/copyImageToQuay.sh --pushtoquay="${PROD_VER} ${latestNext}" ${bundle} ${operands} -v ${PUSHTOQUAYFORCEFLAG}
else
    ${SCRIPT_DIR}/copyImageToQuay.sh --pushtoquay="${PROD_VER} ${latestNext}" ${bundle} ${operands} ${PUSHTOQUAYFORCEFLAG}
fi
