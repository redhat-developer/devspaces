#!/bin/bash
#
# Copyright (c) 2018-2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# for a given operator-bundle & tag, compute the associated IIBs for all OCP versions

VERBOSE=0
QUIET="none"
OCP_VER="v" # by default return all OCP versions

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') PROD_VER="$2"; shift 1;;
    '-o') OCP_VER="$2"; if [[ $OCP_VER != "v"* ]]; then OCP_VER="v${OCP_VER}"; fi; shift 1;;
    '-v') VERBOSE=1; QUIET="none"; shift 0;;
    '-q'|'-qi') VERBOSE=0; QUIET="index"; shift 0;;
    '-qb') VERBOSE=0; QUIET="bundle"; shift 0;;
    '--ds') IMAGE="devspaces-operator-bundle";;
    '--dwo') IMAGE="devworkspace-operator-bundle";;
  esac
  shift 1
done

usage () {
	echo "
Usage: 
  $0 -t PROD_VER [OPTIONS]

Options:
  -o OCP_VER          To limit results to a single OCP version, use this flag
  --ds                Sets PROD_NAME to 'Dev Spaces' and IMAGE_PREFIX to 'devspaces' (default behaviour)
  --dwo               Sets PROD_NAME to 'DevWorkspace Operator' and IMAGE_PREFIX to 'devworkspace'

  -v                  Verbose output: include additional information about what's happening
  -q, -qi             Quiet Index  output: instead of default tabbed table with operator bundle, IIB URL + OCP version; show IIB URL only
  -qb                 Quiet Bundle output: instead of default tabbed table with operator bundle, IIB URL + OCP version; show bundle only
"
}

if [[ -z ${PROD_VER} ]]; then usage; exit 1; fi
if [[ -z ${IMAGE} ]]; then usage; exit 1; fi

# registry-proxy.engineering.redhat.com/rh-osbs/devworkspace-operator-bundle:0.17-1
VER=$(./getLatestImageTags.sh --osbs -c ${IMAGE} --tag ${PROD_VER})
if [[ $VERBOSE -eq 1 ]]; then echo "[DEBUG] $VER"; fi
VER=${VER##*:} # 0.17-1
resultsdbURL="https://resultsdb-api.engineering.redhat.com/api/v2.0/results/latest?testcases=cvp.redhat.detailed.operator-catalog-initialization-bundle-image&item=$IMAGE-container-$VER"
URL=$(curl -sSL "$resultsdbURL" | jq -r '.[][].ref_url')
if [[ $VERBOSE -eq 1 ]]; then echo "[DEBUG] $URL"; fi
if [[ ! $URL ]]; then echo "Could not fetch ref_url from $resultsdbURL"; exit 1; fi
results="$(curl -sSL "${URL}index_images.yml" | tr -d "[]'\n " | tr "," "\n" | sed -r -e "s@(v[0-9.]+):(.+)@$IMAGE:$VER\t\2\t\1@" | grep $OCP_VER)"

for line in "$results"; do
    if [[ $QUIET == "index" ]]; then # show only the index image
        echo "$line" | sed -r -e "s#([^\t]+)\t([^\t]+)\tv.+#\2#"
    elif [[ $QUIET == "bundle" ]]; then # show only the bundle image
        echo "$line" | sed -r -e "s#([^\t]+)\t([^\t]+)\tv.+#\1#"
    else
        echo "$line"
    fi 
done
