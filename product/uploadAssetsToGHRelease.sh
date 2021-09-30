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

if [[ $(which gh | grep 'no') ]]; then 
  #no GH CLI installed, install it
  brew install gh
  gh auth login --with-token ${GITHUB_TOKEN}
else
  #login again for safety
  gh auth login --with-token ${GITHUB_TOKEN}
fi

# check if existing release exists
#RELEASE_ID=$(curlWithToken -H "Accept: application/vnd.github.v3+json" $releases_URL | jq -r --arg PREFIX "${PREFIX}" --arg CSV_VERSION "${CSV_VERSION}" '.[] | select(.name=="Assets for the '$CSV_VERSION' '$PREFIX' release")|.url' || true); RELEASE_ID=${RELEASE_ID##*/}
if [[ $(gh release list | grep ${CSV_VERSION}) ]]; then
  #no existing release, create it
  gh release create "${CSV_VERSION}-${PREFIX}-assets" --target "${MIDSTM_BRANCH}" --title "Assets for the ${CSV_VERSION} ${PREFIX} release" --notes "Container build asset files for ${CSV_VERSION}" --prerelease
fi

# upload artifacts for each platform 
for fileToPush in $fileList; do
    # attempt to upload a new file
    echo "Uploading new asset $fileToPush"
    gh release upload "${CSV_VERSION}-${PREFIX}-assets" ${fileToPush} --clobber
done

#logout ¯\_(ツ)_/¯
gh auth logout github.com 