#!/bin/bash
#
# Copyright (c) 2018-2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# script to query latest IIBs (one per OCP version) for a given version of CRW

usage () {
	echo "
Usage: 
  $0 -t PROD_VERSION

Options:
  -o OCP_VERSION       To limit results to a single OCP version, use this flag
  -p PRODUCT_NAME      Defaults to 'Dev Spaces'; label on output when multiple OCP versions specified
  -i IMAGE_PREFIX      Defaults to 'devspaces'; used in registry-proxy.engineering.redhat.com/rh-osbs/IMAGE_PREFIX to filter results
  -c 'csv1 csv2 ...'   Defaults to 'operator-bundle'; used to filter results

  --ds                 Sets PRODUCT_NAME to 'Dev Spaces' and IMAGE_PREFIX to 'devspaces' (default behaviour)
  --crw                Sets PRODUCT_NAME to 'CodeReady Workspaces' and IMAGE_PREFIX to 'codeready-workspaces'
  --dwo                Sets PRODUCT_NAME to 'DevWorkspace Operator' and IMAGE_PREFIX to 'devworkspace'
  --wto                Sets PRODUCT_NAME to 'Web Terminal Operator' and IMAGE_PREFIX to 'web-terminal'

  -q                   Quieter output
"
}

QUIET=0
OCP_VERSION="" # if not set, check for all

crwDefaults () {
  PROD_VERSION="2.15"
  PRODUCT_NAME="CodeReady Workspaces"
  IMAGE_PREFIX="codeready-workspaces"
  CSVs="operator-metadata operator-bundle"
}

dsDefaults() {
  PRODUCT_NAME="Dev Spaces"
  IMAGE_PREFIX="devspaces"
  CSVs="operator-bundle"
}

dwoDefaults() {
  PRODUCT_NAME="DevWorkspace Operator"
  IMAGE_PREFIX="devworkspace"
  CSVs="operator-bundle"
}

wtoDefaults() {
  PRODUCT_NAME="Web Terminal Operator"
  IMAGE_PREFIX="web-terminal"
  CSVs="operator-bundle"
}

dsDefaults

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') PROD_VERSION="$2"; shift 1;;
    '-o') OCP_VERSION="$2"; shift 1;;
    '-p') PRODUCT_NAME="$2"; shift 1;;
    '-c') CSVs="$2"; shift 1;;
    '-i') IMAGE_PREFIX="$2"; shift 1;;
    '-q') QUIET=1; shift 0;;
    '--crw') crwDefaults;;
    '--ds')   dsDefaults;;
    '--dwo') dwoDefaults;;
    '--wto') wtoDefaults;;
  esac
  shift 1
done

if [[ -z ${PROD_VERSION} ]]; then usage; exit 1; fi

# override for old releases
if [[ $PROD_VERSION == "2.15" ]]; then crwDefaults; fi

if [[ $QUIET -eq 0 ]]; then
  echo "Checking for latest IIBs for $PRODUCT_NAME ${PROD_VERSION} ..."; echo
fi
for csv in $CSVs; do
  lastcsv=$(curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=30&contains=${IMAGE_PREFIX}" | \
jq ".raw_messages[].msg.index | .added_bundle_images[0]" -r | sort -uV | grep "${csv}:${PROD_VERSION}" | tail -1 | \
sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/${IMAGE_PREFIX}-##");

  if [[ $OCP_VERSION == "" ]]; then
    curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=30&contains=${IMAGE_PREFIX}" | \
      jq ".raw_messages[].msg.index | [.added_bundle_images[0], .index_image, .ocp_version] | @tsv" -r | sort -uV | \
      grep "${lastcsv}" | sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/${IMAGE_PREFIX}-#  #";
    echo;
  else
    curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=30&contains=${IMAGE_PREFIX}" | \
      jq ".raw_messages[].msg.index | [.added_bundle_images[0], .index_image, .ocp_version] | @tsv" -r | sort -uV | \
      grep "${lastcsv}" | grep "v${OCP_VERSION}" | sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/${IMAGE_PREFIX}-.+\t([^\t]+)\tv${OCP_VERSION}#\1#";
  fi
done

