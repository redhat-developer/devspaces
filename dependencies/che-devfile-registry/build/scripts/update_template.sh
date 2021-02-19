#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# List all images referenced in meta.yaml files
#

set -e

unset TEMPLATE

MIDSTM_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT_TAG=${MIDSTM_BRANCH#*-}; DEFAULT_TAG=${DEFAULT_TAG%%-*};
[[ ${DEFAULT_TAG} == "2" ]] && DEFAULT_TAG="latest"

usage () {
    echo "Usage:   $0 -t TEMPLATE"
    echo "Options:
    --crw-version ${DEFAULT_TAG}     (compute from MIDSTM_BRANCH if not set)
      "
    exit 1
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') TEMPLATE="$2"; shift 1;;
    '--help'|'-h') usage;;
  esac
  shift 1
done

if [[ -z "${TEMPLATE+x}" ]]; then usage; fi

sed -i \
    -e "s|Eclipse Che|CodeReady Workspaces|g" \
    -e "s|CHE_|CRW_|g" \
    -e "s|quay.io/eclipse/che-devfile-registry|registry.redhat.io/codeready-workspaces/devfileregistry-rhel8|g" \
    -e "s|nightly|\'${DEFAULT_TAG}\'|g" \
    -e "s|che|codeready|g" \
    ${TEMPLATE}
