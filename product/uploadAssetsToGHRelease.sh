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
CSV_VERSION="2.y.0" # csv 2.y.0
ASSET_NAME=""
fileList=""
DELETE_ASSETS=0 # this also deletes the release in which the assets are stored
PUBLISH_ASSETS=0 # publish asset(s) to GH
PULL_ASSETS=0 # pull asset(s) from GH
PRE_RELEASE="--prerelease" # by default create pre-releases
MIDSTM_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "crw-2-rhel-8")
if [[ ${MIDSTM_BRANCH} != "crw-"*"-rhel-"* ]]; then MIDSTM_BRANCH="crw-2-rhel-8"; fi

usageGHT() {
    echo 'Setup:

First, export your GITHUB_TOKEN:

  export GITHUB_TOKEN="...github-token..."
'
  usage
}
usage () {
    echo "Usage:

  $0 -v CRW_CSV_VERSION -n ASSET_NAME file1.tar.gz [file2.tar.gz ...]

Options:
  -b branch               branch from which to create tag + release; defaults to $MIDSTM_BRANCH
  -d, --delete-assets     delete release + asset file(s) defined by CSV_VERSION and ASSET_NAME
  -a, --publish-assets    publish asset file(s) to release defined by CSV_VERSION and ASSET_NAME
  -p, --pull-assets       fetch asset file(s) from release defined by CSV_VERSION and ASSET_NAME
  --release               by default, do a pre-release; use this flag to create a full release (for GA only)
  -h, --help              show this help

Examples:

  $0 --delete-assets -v 2.y.0 -n traefik              # delete release, tag, and asset(s)
  $0 --publish-assets -v 2.y.0 -n traefik asset-*gz   # publish specific asset(s)
  $0 --pull-assets -v 2.y.0 -n traefik asset-*gz      # pull specific asset(s)
  $0 --pull-assets -v 2.y.0 -n traefik                # pull all assets
"
    exit
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-v') CSV_VERSION="$2"; shift 1;;
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    '-ght') GITHUB_TOKEN="$2"; export GITHUB_TOKEN="${GITHUB_TOKEN}"; shift 1;;
    '-n'|'--asset-name')       ASSET_NAME="$2"; shift 1;;

    '-d'|'--delete-assets')    DELETE_ASSETS=1;;
    '-a'|'--publish-assets')   PUBLISH_ASSETS=1;;
    '-p'|'--pull-assets')      PULL_ASSETS=1;;
    '--prerelease')            PRE_RELEASE="$1";; # --prerelease
    '--release')               PRE_RELEASE="";;   # not a prerelease
    '-h'|'--help') usageGHT;;
    *) fileList="${fileList} $1";;
  esac
  shift 1
done

if [[ ! "${GITHUB_TOKEN}" ]]; then usageGHT; fi
if [[ $CSV_VERSION == "2.y.0" ]]; then echo "Error: must specify CSV_VERSION with -v flag.";echo; usage; fi
if [[ $ASSET_NAME == "" ]]; then echo "Error: must specify ASSET_NAME with -n flag.";echo; usage; fi
if [[ $DELETE_ASSETS -eq 0 ]] && [[ $PUBLISH_ASSETS -eq 0 ]] && [[ $PULL_ASSETS -eq 0 ]]; then 
  echo "Error: must specify which operation to run:
  --delete-assets
  --publish-assets
  --pull-assets"; echo; usage
fi

export GITHUB_TOKEN=${GITHUB_TOKEN}

# this also deletes the release in which the assets are stored
if [[ $DELETE_ASSETS -eq 1 ]]; then
  #check if release exists
  if [[ $(hub release | grep ${CSV_VERSION}-${ASSET_NAME}-assets) ]]; then
    echo "Delete release ${CSV_VERSION}-${ASSET_NAME}-assets"
    hub release delete "${CSV_VERSION}-${ASSET_NAME}-assets"
    hub push origin :"${CSV_VERSION}-${ASSET_NAME}-assets"
  else
    echo "No release with tag ${CSV_VERSION}-${ASSET_NAME}-assets"
  fi
fi

if [[ $PUBLISH_ASSETS -eq 1 ]]; then
  if [[ -z $fileList ]]; then echo "Error: no files specified to publish!"; usage; fi
  # check if release exists
  if [[ ! $(hub release | grep ${CSV_VERSION}-${ASSET_NAME}-assets) ]]; then
    #no existing release, create it
    hub release create -t "${MIDSTM_BRANCH}" \
      -m "Assets for the ${CSV_VERSION} ${ASSET_NAME} release" -m "Container build asset files for ${CSV_VERSION}" \
      ${PRE_RELEASE} "${CSV_VERSION}-${ASSET_NAME}-assets"
  fi

  # upload artifacts for each platform 
  for fileToPush in $fileList; do
    # attempt to upload a new file
    echo "Upload new asset $fileToPush"
    hub release edit -a ${fileToPush} "${CSV_VERSION}-${ASSET_NAME}-assets" \
      -m "Assets for the ${CSV_VERSION} ${ASSET_NAME} release" -m "Container build asset files for ${CSV_VERSION}"
  done
fi

if [[ $PULL_ASSETS -eq 1 ]]; then
  if [[ -z $fileList ]]; then 
    echo "Download all assets"
    hub release download "${CSV_VERSION}-${ASSET_NAME}-assets"
  else 
    #attempt to download asset(s)
    for fileToFetch in $fileList; do
      echo "Download asset $fileToFetch"
      hub release download "${CSV_VERSION}-${ASSET_NAME}-assets" -i ${fileToFetch}
    done
  fi
fi
