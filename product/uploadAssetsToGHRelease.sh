#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
# push locally built asset* files to github

set -e

# defaults
CSV_VERSION=2.y.0 # csv 2.y.0
PREFIX=""
fileList=""

MIDSTM_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "crw-2-rhel-8")
if [[ ${MIDSTM_BRANCH} != "crw-"*"-rhel-"* ]]; then MIDSTM_BRANCH="crw-2-rhel-8"; fi

usage () {
    echo "
Usage:   $0 -v [CRW CSV_VERSION] --prefix [subproject prefix] file1.tar.gz file2.tar.gz
Example: $0 -v 2.y.0 --prefix traefik asset-*gz
"
    exit
}

if [[ $# -lt 5 ]]; then usage; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-v') CSV_VERSION="$2"; shift 1;;
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    '-ght') GITHUB_TOKEN="$2"; export GITHUB_TOKEN="${GITHUB_TOKEN}"; shift 1;;
    '--prefix') PREFIX="$2"; shift 1;;
    '--help'|'-h') usage;;
    *) fileList="${fileList} $1";;
  esac
  shift 1
done

export GITHUB_TOKEN=${GITHUB_TOKEN}

# check if existing release exists
if [[ $(hub release | grep ${CSV_VERSION}-${PREFIX}-assets) == "" ]]; then
  #no existing release, create it
  hub release create -t "${MIDSTM_BRANCH}" -m "Assets for the ${CSV_VERSION} ${PREFIX} release" -m "Container build asset files for ${CSV_VERSION}" --prerelease "${CSV_VERSION}-${PREFIX}-assets"
fi

if [[ $(hub release download -i asset_manifest.txt | grep 'pattern did not match') == "" ]]; then #Manifest exists
  hub release download -i asset_manifest.txt
else
  touch asset_manifest.txt
fi

# upload artifacts for each platform 
for fileToPush in $fileList; do
    # attempt to upload a new file
    echo "Uploading new asset $fileToPush"
    hub release edit -a ${fileToPush} "${CSV_VERSION}-${PREFIX}-assets" -m "Assets for the ${CSV_VERSION} ${PREFIX} release" -m "Container build asset files for ${CSV_VERSION}"

    if [[ $(grep ${fileToPush} asset_manifest.txt) ]]; then
      sed -i "s/${fileToPush}.*/${fileToPush} : `date`/" asset_manifest.txt
    else
      echo "${fileToPush} : `date`" >> asset_manifest.txt
    fi

done

#push asset_manifest to releases and delete local copy
hub release edit -a asset_manifest.txt "${CSV_VERSION}-${PREFIX}-assets" -m "Assets for the ${CSV_VERSION} ${PREFIX} release" -m "Container build asset files for ${CSV_VERSION}"
