#!/bin/bash
#
# Copyright (c) 2019-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

set -e

DEFAULT_TAG="nightly"
DEFAULT_REGISTRY="quay.io"
DEFAULT_ORGANIZATION="eclipse"

TAG=${TAG:-$DEFAULT_TAG}
REGISTRY=${REGISTRY:-$DEFAULT_REGISTRY}
ORGANIZATION=${ORGANIZATION:-$DEFAULT_ORGANIZATION}

if [ "$TAG" = "$DEFAULT_TAG" ] && [ "$ORGANIZATION" = "$DEFAULT_ORGANIZATION" ] && [ "$REGISTRY" = "$DEFAULT_REGISTRY" ]; then
  echo "No patching necessary"
  exit 0
fi

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
readarray -d '' devfiles < <(find devfiles -name 'devfile.yaml' -print0)
while read -r line; do
  image_name=$(echo "$line" | tr -s ' ' | cut -f 1 -d ' ')
  echo "Updating devfiles using 'quay.io/eclipse/$image_name:nightly' to '$REGISTRY/$ORGANIZATION/$image_name:$TAG'"
  sed -i "s|quay.io/eclipse/$image_name:nightly|$REGISTRY/$ORGANIZATION/$image_name:$TAG|g" "${devfiles[@]}"
done <"${SCRIPT_DIR}"/base_images
