#!/bin/bash
#
# Copyright (c) 2021-22 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# use this script to update the deploy/openshift/*-registry.yaml file
# script is shared with both DS devfile and plugin registries

unset SOURCE_TEMPLATE
unset DS_VERSION
MIDSTM_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
DS_VERSION=${MIDSTM_BRANCH#devspaces-}; DS_VERSION=${DS_VERSION%-rhel*} # devspaces-3.y-rhel-8 ==> 3.y
DOCKER_IMAGE="registry.redhat.io/devspaces/REG_NAMEregistry-rhel8"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-rn') REG_NAME="$2"; shift 1;;
    '-s') SOURCE_TEMPLATE="$2"; shift 1;;
    '-t') DS_VERSION="$2"; shift 1;; # 3.y
    '-i') DOCKER_IMAGE="$2"; shift 1;; # registry.redhat.io/devspaces/*registry-rhel8
    '--help'|'-h') usage; shift 1;;
  esac
  shift 1
done

if [[ ${DOCKER_IMAGE} == *"REG_NAMEregistry"* ]] && [[ ${REG_NAME} ]]; then
  DOCKER_IMAGE="registry.redhat.io/devspaces/${REG_NAME}registry-rhel8"
fi

usage () {
	echo
    echo "Usage:     ${0##*/} -rn REG_NAME -s /path/to/devspaces-REG_NAME-registry.yaml -i DOCKER_IMAGE -t 3.y"
    echo "Example:   ${0##*/} -rn devfile -s /path/to/deploy/openshift/devspaces-devfile-registry.yaml"
    echo "Example:   ${0##*/} -rn plugin -s /path/to/deploy/openshift/devspaces-plugin-registry.yaml"
    echo "Options:
    -rn Red Hat OpenShift Dev Spaces registry name (plugin or devfile); must be set
    -t Red Hat OpenShift Dev Spaces ${REG_NAME} registry image tag (compute from MIDSTM_BRANCH if not set)
    -i Red Hat OpenShift Dev Spaces ${REG_NAME} registry image (default to ${DOCKER_IMAGE})
    --help, -h            help
      "
    exit 1
}

# file must exist and be writeable
if [[ -z "${SOURCE_TEMPLATE}" ]] || [[ ! -w "${SOURCE_TEMPLATE}" ]]; then 
  echo
  echo "[ERROR] Source template file not found or not writeable: ${SOURCE_TEMPLATE}"
  usage
fi

# must have a registry name and a version at minimum
if [[ ! ${REG_NAME} ]]; then
  echo
  echo "[ERROR] Registry name must equal to plugin or devfile: ${REG_NAME}"
  usage
fi
if [[ ${REG_NAME} != "plugin" ]] && [[ ${REG_NAME} != "devfile" ]]; then
  echo
  echo "[ERROR] Registry name must equal to plugin or devfile: ${REG_NAME}"
  usage
fi
if [[ ! ${DS_VERSION} ]]; then 
  echo "[ERROR] DS_VERSION name be set: ${DS_VERSION}"
  usage
fi
DEFAULT_TAG=${DS_VERSION}
[[ ${DEFAULT_TAG} == "2" ]] && DEFAULT_TAG="next"

set -e

sed -i \
    -e "s|Eclipse Che|Red Hat OpenShift Dev Spaces|g" \
    -e "s|CHE_|DS_|g" \
    -e "s|che|devspaces|g" \
    -e "s|Che|Dev Spaces|g" \
    "${SOURCE_TEMPLATE}"

yq -ryiY "(.parameters[] | select(.name == \"IMAGE\") | .value ) = \"${DOCKER_IMAGE}\"" "${SOURCE_TEMPLATE}"
yq -ryiY "(.parameters[] | select(.name == \"IMAGE\") | .description ) = \"Red Hat OpenShift Dev Spaces ${REG_NAME} registry container image. Defaults to ${DOCKER_IMAGE}\"" "${SOURCE_TEMPLATE}"
yq -ryiY "(.parameters[] | select(.name == \"IMAGE_TAG\") | .value ) = \"${DEFAULT_TAG}\"" "${SOURCE_TEMPLATE}"

# shellcheck disable=SC2005 disable=SC2046
# why this extra echo?
echo "$(echo '#
# Copyright (c) 2018-'$(date +%Y)' Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
---' | cat - "${SOURCE_TEMPLATE}")" > "${SOURCE_TEMPLATE}"
