#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

set -e
set -x

unset SOURCE_TEMPLATE
unset CSV_VERSION
unset CRW_VERSION

MIDSTM_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CRW_VERSION=${MIDSTM_BRANCH#*-}
DOCKER_IMAGE="registry.redhat.io/codeready-workspaces/devfileregistry-rhel8"

usage () {
    echo "Usage:     $0 -s SOURCE_TEMPLATE"
    echo "Example:   $0 -s crw-devfile-registry.yaml -i ${DOCKER_IMAGE} -t 2.y"
    echo "Options:
    -t Codeready Workspaces version (compute from MIDSTM_BRANCH if not set)
    -i Codeready Workspaces devfile registry image (default to ${DOCKER_IMAGE})
    --help, -h            help
      "
    exit 1
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-s') SOURCE_TEMPLATE="$2"; shift 1;;
    '-t') CRW_VERSION="$2"; shift 1;; # 2.y
    '-i') DOCKER_IMAGE="$2"; shift 1;; # 2.y
    '--help'|'-h') usage;;
  esac
  shift 1
done

DEFAULT_TAG=${CRW_VERSION%%-*}
[[ ${DEFAULT_TAG} == "2" ]] && DEFAULT_TAG="nightly"

if [[ -z "${SOURCE_TEMPLATE}" ]]; then usage; fi

sed -i \
    -e "s|Eclipse Che|CodeReady Workspaces|g" \
    -e "s|CHE_|CRW_|g" \
    -e "s|che|codeready|g" \
    -e "s|Che|Codeready|g" \
    ${SOURCE_TEMPLATE}

yq -ryiY "(.parameters[] | select(.name == \"IMAGE\") | .value ) = \"${DOCKER_IMAGE}\"" ${SOURCE_TEMPLATE}
yq -ryiY "(.parameters[] | select(.name == \"IMAGE\") | .description ) = \"CodeReady Workspaces devfile registry Docker image. Defaults to ${DOCKER_IMAGE}\"" ${SOURCE_TEMPLATE}
yq -ryiY "(.parameters[] | select(.name == \"IMAGE_TAG\") | .value ) = \"${DEFAULT_TAG}\"" ${SOURCE_TEMPLATE}

echo "$(echo '#
# Copyright (c) 2018-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
---' | cat - ${SOURCE_TEMPLATE})" > ${SOURCE_TEMPLATE}
