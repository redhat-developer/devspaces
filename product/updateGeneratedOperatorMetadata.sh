#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to fetch latest operator-metadata image, extract contents, and publish to 
# https://github.com/redhat-developer/codeready-workspaces-images/tree/${MIDSTM_BRANCH}/codeready-workspaces-operator-metadata-generated/

usage () 
{
    echo "Usage: $0 -b [midstream branch] -t [quay tag] -s [sources to update]"
    echo "Example: $0 -b crw-2.y-rhel-8 -t 2.y -s /path/to/github/redhat-developer/codeready-workspaces-images/"
	echo ""
    exit
}

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-s') SOURCE_DIR="$2"; shift 1;; # dir to update
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    '-t') CRW_VERSION="$2"; shift 1;;
    '-h') usage;;
  esac
  shift 1
done

if [[ ! ${MIDSTM_BRANCH} ]]; then usage; fi
if [[ ! ${SOURCE_DIR} ]]; then usage; fi

if [[ ! -x ${SCRIPTPATH}/containerExtract.sh ]]; then
    curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/${MIDSTM_BRANCH}/product/containerExtract.sh
    chmod +x containerExtract.sh
fi

${SCRIPTPATH}/containerExtract.sh quay.io/crw/crw-2-rhel8-operator-metadata:${CRW_VERSION} || true
rm -fr ${SOURCE_DIR}/codeready-workspaces-operator-metadata-generated
rsync -zrlt /tmp/quay.io-crw-crw-2-rhel8-operator-metadata-${CRW_VERSION}-*/* \
    ${SOURCE_DIR}/codeready-workspaces-operator-metadata-generated/
pushd ${SOURCE_DIR}/ >/dev/null || exit 1
    git add codeready-workspaces-operator-metadata-generated || true
    git commit -m "[brew] Publish CSV with generated digests" codeready-workspaces-operator-metadata-generated || true
    git pull origin "${MIDSTM_BRANCH}" || true
    git push origin "${MIDSTM_BRANCH}"
popd >/dev/null || true

# cleanup
rm -fr /tmp/quay.io-crw-crw-2-rhel8-operator-metadata-${CRW_VERSION}-*
