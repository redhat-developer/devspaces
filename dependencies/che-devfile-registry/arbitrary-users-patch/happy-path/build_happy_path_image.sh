#!/bin/bash
#
# Copyright (c) 2018-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)

DEFAULT_REGISTRY="quay.io"
DEFAULT_ORGANIZATION="eclipse"
DEFAULT_TAG="nightly"

REGISTRY=${REGISTRY:-${DEFAULT_REGISTRY}}
ORGANIZATION=${ORGANIZATION:-${DEFAULT_ORGANIZATION}}
TAG=${TAG:-${DEFAULT_TAG}}

NAME_FORMAT="${REGISTRY}/${ORGANIZATION}"

PUSH_IMAGES=false
if [ "$1" == "--push" ]; then
  PUSH_IMAGES=true
fi

# Build image for happy-path tests with precashed mvn dependencies
docker build -t "${NAME_FORMAT}/happy-path:${TAG}" --no-cache --build-arg TAG="${TAG}" "${SCRIPT_DIR}"/  | cat
if ${PUSH_IMAGES}; then
    echo "Pushing ${NAME_FORMAT}/happy-path:${TAG}" to remote registry
    docker push "${NAME_FORMAT}/happy-path:${TAG}" | cat
fi
