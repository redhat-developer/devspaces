#!/bin/bash
#
# Copyright (c) 2019-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# List all images referenced in meta.yaml files
#

set -e

unset SOURCE
unset DESTINATION

MIDSTM_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT_TAG=${MIDSTM_BRANCH#*-}; DEFAULT_TAG=${DEFAULT_TAG%%-*};

usage () {
    echo "Usage:   $0 -s SOURCE_FILE -d DESTINATION_FILE"
    echo "Options:
    --crw-version ${DEFAULT_TAG}     (compute from MIDSTM_BRANCH if not set)
      "
    exit 1
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-s') SOURCE="$2"; shift 1;;
    '-d') DESTINATION="$2"; shift 1;;
    '--help'|'-h') usage;;
  esac
  shift 1
done

if [[ -z "${SOURCE+x}" ]]; then usage; fi
if [[ -z "${DESTINATION+x}" ]]; then usage; fi

cp ${SOURCE} ${DESTINATION}

sed -i \
    -e "s|Eclipse Che|CodeReady Workspaces|g" \
    -e "s|CHE_|CODEREADY_|g" \
    -e "s|quay.io/eclipse/che-devfile-registry|registry.redhat.io/codeready-workspaces/devfileregistry-rhel8|g" \
    -e "s|value: nightly|value: \'${DEFAULT_TAG}\'|g" \
    -e "s|che|codeready|g" \
    ${DESTINATION}
