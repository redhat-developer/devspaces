#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
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
DEFAULT_TAG="next"

REGISTRY=${REGISTRY:-${DEFAULT_REGISTRY}}
ORGANIZATION=${ORGANIZATION:-${DEFAULT_ORGANIZATION}}
TAG=${TAG:-${DEFAULT_TAG}}

NAME_FORMAT="${REGISTRY}/${ORGANIZATION}"

PUSH_IMAGES=false
if [ "$1" == "--push" ]; then
  PUSH_IMAGES=true
fi

while read -r line; do
  base_image_name=$(echo "$line" | tr -s ' ' | cut -f 1 -d ' ')
  base_image=$(echo "$line" | tr -s ' ' | cut -f 2 -d ' ')
  echo "Building ${NAME_FORMAT}/${base_image_name}:${TAG} based on $base_image ..."
  docker build -t "${NAME_FORMAT}/${base_image_name}:${TAG}" --no-cache --build-arg FROM_IMAGE="$base_image" "${SCRIPT_DIR}"/ | cat
  if ${PUSH_IMAGES}; then
    echo "Pushing ${NAME_FORMAT}/${base_image_name}:${TAG}" to remote registry
    docker push "${NAME_FORMAT}/${base_image_name}:${TAG}" | cat
  fi
done < "${SCRIPT_DIR}"/base_images
