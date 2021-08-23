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
Usage:   $0 -v [CRW CSV_VERSION] --prefix [unique prefix] file1.tar.gz file2.tar.gz
Example: $0 -v 2.y.0 --prefix crw-theia
"
    exit
}

if [[ $# -lt 1 ]]; then usage; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-v') CSV_VERSION="$2"; shift 1;;
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    '-ght') GITHUB_TOKEN="$2"; shift 1;;
    '--prefix') PREFIX="$2"; shift 1;;
    '--help'|'-h') usage;;
    *) fileList="$1";;
  esac
  shift 1
done

curl -XPOST -H 'Authorization:token '"${GITHUB_TOKEN}" --data '{"tag_name": "'"${CSV_VERSION}"'", "target_commitish": "'"${MIDSTM_BRANCH}"'", "name": "'"${CSV_VERSION}"'-ci-assets", "body": "Container build asset files for '"${CSV_VERSION}"'", "draft": true, "prerelease": true}' https://api.github.com/repos/redhat-developer/codeready-workspaces-chectl/releases > "/tmp/${CSV_VERSION}"
# Extract the id of the release from the creation response
RELEASE_ID="$(jq -r .id /tmp/${CSV_VERSION})"

# upload artifacts for each platform 
for fileName in $fileList; do
    if [[ ${PREFIX} ]]; then 
        fileToPush="${PREFIX}-${fileName}"
    else 
        fileToPush="${fileName}"
    fi
    curl -XPOST -H 'Authorization:token '"$GITHUB_TOKEN" -H 'Content-Type:application/octet-stream' --data-binary @"${fileToPush}" "https://uploads.github.com/repos/redhat-developer/codeready-workspaces-images/releases/${RELEASE_ID}/assets?name=${fileToPush}"
done
