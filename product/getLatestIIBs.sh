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
  $0 -t PROD_VER [OPTIONS]

Options:
  -o OCP_VER          To limit results to a single OCP version, use this flag
  -p PROD_NAME        Defaults to 'Dev Spaces'; label on output when multiple OCP versions specified
  -i IMAGE_PREFIX     Defaults to 'devspaces'; used in registry-proxy.engineering.redhat.com/rh-osbs/IMAGE_PREFIX to filter results
  -c 'csv1 csv2 ...'  Defaults to 'operator-bundle'; used to filter results

  --ds                Sets PROD_NAME to 'Dev Spaces' and IMAGE_PREFIX to 'devspaces' (default behaviour)
  --crw               Sets PROD_NAME to 'CodeReady Workspaces' and IMAGE_PREFIX to 'codeready-workspaces'
  --dwo               Sets PROD_NAME to 'DevWorkspace Operator' and IMAGE_PREFIX to 'devworkspace'
  --wto               Sets PROD_NAME to 'Web Terminal Operator' and IMAGE_PREFIX to 'web-terminal'

  -v                  Verbose output: include additional information about what's happening
  -q                  Quieter output: instead of default tabbed table with operator bundle, IIB URL + OCP version; show IIB URL only
"
}

VERBOSE=0
QUIET=0
OCP_VER="" # if not set, check for all available versions, and return multiple results

crwDefaults () {
  PROD_VER="2.15"
  PROD_NAME="CodeReady Workspaces"
  IMAGE_PREFIX="codeready-workspaces"
  CSVs="operator-metadata operator-bundle"
}

dsDefaults() {
  PROD_NAME="Dev Spaces"
  IMAGE_PREFIX="devspaces"
  CSVs="operator-bundle"
}

dwoDefaults() {
  PROD_NAME="DevWorkspace Operator"
  IMAGE_PREFIX="devworkspace"
  CSVs="operator-bundle"
}

wtoDefaults() {
  PROD_NAME="Web Terminal Operator"
  IMAGE_PREFIX="web-terminal"
  CSVs="operator-bundle"
}

dsDefaults

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') PROD_VER="$2"; shift 1;;
    '-o') OCP_VER="$2"; shift 1;;
    '-p') PROD_NAME="$2"; shift 1;;
    '-c') CSVs="$2"; shift 1;;
    '-i') IMAGE_PREFIX="$2"; shift 1;;
    '-v') VERBOSE=1; QUIET=0; shift 0;;
    '-q') VERBOSE=0; QUIET=1; shift 0;;
    '--crw') crwDefaults;;
    '--ds')   dsDefaults;;
    '--dwo') dwoDefaults;;
    '--wto') wtoDefaults;;
  esac
  shift 1
done

if [[ -z ${PROD_VER} ]]; then usage; exit 1; fi

# override for old releases
if [[ $PROD_VER == "2.15" ]]; then crwDefaults; fi

for csv in $CSVs; do
  if [[ $VERBOSE -eq 1 ]]; then
    echo; echo "Checking for latest IIBs for $PROD_NAME ${PROD_VER} ${csv} ..."; echo
  fi
  lastcsv=$(curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=30&contains=${IMAGE_PREFIX}" | \
jq ".raw_messages[].msg.index | .added_bundle_images[0]" -r | sort -uV | grep "${csv}:${PROD_VER}" | tail -1 | \
sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/${IMAGE_PREFIX}-##");

  if [[ $OCP_VER == "" ]]; then
    line="$(curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=30&contains=${IMAGE_PREFIX}" | \
        jq ".raw_messages[].msg.index | [.added_bundle_images[0], .index_image, .ocp_version] | @tsv" -r | sort -uV | \
        grep "${lastcsv}" | sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/${IMAGE_PREFIX}-#  #")"
    if [[ $QUIET -eq 1 ]]; then # show only the index images
      echo "$line" | sed -r -e "s#[^\t]+\t([^\t]+)\tv.+#\1#"
    else
      echo "$line"
    fi
  else
    line="$(curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=30&contains=${IMAGE_PREFIX}" | \
      jq ".raw_messages[].msg.index | [.added_bundle_images[0], .index_image, .ocp_version] | @tsv" -r | sort -uV | \
      grep "${lastcsv}" | grep "v${OCP_VER}" | sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/${IMAGE_PREFIX}-#  #")"
    if [[ $QUIET -eq 1 ]]; then # show only the index images
      echo "$line" | sed -r -e "s#[^\t]+\t([^\t]+)\tv.+#\1#"
    else
      echo "$line"
    fi
  fi
done

