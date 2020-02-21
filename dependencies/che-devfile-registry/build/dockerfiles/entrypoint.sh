#!/bin/bash
#
# Copyright (c) 2018-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Updates plugin runner images to point a registry defined by environment
# variables
#     CHE_DEVFILE_IMAGES_REGISTRY_URL
#     CHE_DEVFILE_IMAGES_REGISTRY_ORGANIZATION
#     CHE_DEVFILE_IMAGES_REGISTRY_TAG
#
# By default, this script will operate on the `/var/www/html/devfiles` directory.
# This can be overridden by the environment variable $DEVFILES_DIR
#
# In addition, this script will perform the necessary set up for the offline
# devfile registry, replacing placeholders in all devfiles based off environment
# variable
#     CHE_DEVFILE_REGISTRY_URL
# which should be set to the public endpoint for this registry.
#
# Will execute any arguments on completion (`exec $@`)

set -e

REGISTRY=${CHE_DEVFILE_IMAGES_REGISTRY_URL}
ORGANIZATION=${CHE_DEVFILE_IMAGES_REGISTRY_ORGANIZATION}
TAG=${CHE_DEVFILE_IMAGES_REGISTRY_TAG}
PUBLIC_URL=${CHE_DEVFILE_REGISTRY_URL}

DEFAULT_DEVFILES_DIR="/var/www/html/devfiles"
DEVFILES_DIR="${DEVFILES_DIR:-${DEFAULT_DEVFILES_DIR}}"
INDEX_JSON="${DEVFILES_DIR}/index.json"

# Regex used to break an image reference into groups:
#   \1 - Whitespace and (optional) quotation preceding image reference
#   \2 - Registry portion of image, e.g. (quay.io)/eclipse/che-theia:tag
#   \3 - Organization portion of image, e.g. quay.io/(eclipse)/che-theia:tag
#   \4 - Image name portion of image, e.g. quay.io/eclipse/(che-theia):tag
#   \5 - Optional image digest identifier (empty for tags), e.g. quay.io/eclipse/che-theia(@sha256):digest
#   \6 - Tag of image or digest, e.g. quay.io/eclipse/che-theia:(tag)
#   \7 - Optional quotation following image reference
IMAGE_REGEX='([[:space:]]*"?)([._:a-zA-Z0-9-]*)/([._a-zA-Z0-9-]*)/([._a-zA-Z0-9-]*)(@sha256)?:([._a-zA-Z0-9-]*)("?)'

# We can't use the `-d` option for readarray because
# registry.centos.org/centos/httpd-24-centos7 ships with Bash 4.2
# The below command will fail if any path contains whitespace
readarray -t devfiles < <(find "${DEVFILES_DIR}" -name 'devfile.yaml')
readarray -t metas < <(find "${DEVFILES_DIR}" -name 'meta.yaml')
for devfile in "${devfiles[@]}"; do
  echo "Checking devfile $devfile"
  # Need to update each field separately in case they are not defined.
  # Defaults don't work because registry and tags may be different.
  if [ -n "$REGISTRY" ]; then
    echo "    Updating image registry to $REGISTRY"
    sed -i -E "s|image:$IMAGE_REGEX|image:\1${REGISTRY}/\3/\4\5:\6\7|" "$devfile"
  fi
  if [ -n "$ORGANIZATION" ]; then
    echo "    Updating image organization to $ORGANIZATION"
    sed -i -E "s|image:$IMAGE_REGEX|image:\1\2/${ORGANIZATION}/\4\5:\6\7|" "$devfile"
  fi
  if [ -n "$TAG" ]; then
    echo "    Updating image tag to $TAG"
    sed -i -E "s|image:$IMAGE_REGEX|image:\1\2/\3/\4:${TAG}\7|" "$devfile"
  fi
done

if [ -n "$PUBLIC_URL" ]; then
  echo "Updating devfiles to point at internal project zip files"
  PUBLIC_URL=${PUBLIC_URL%/}
  sed -i "s|{{ DEVFILE_REGISTRY_URL }}|${PUBLIC_URL}|" "${devfiles[@]}" "${metas[@]}" "$INDEX_JSON"
else
  if grep -q '{{ DEVFILE_REGISTRY_URL }}' "${devfiles[@]}"; then
    echo "WARNING: environment variable 'CHE_DEVFILE_REGISTRY_URL' not configured" \
         "for an offline build of this registry. This may cause issues with importing" \
         "projects in a workspace."
    # Experimental workaround -- detect service IP for che-devfile-registry
    # Depends on service used being named 'che-devfile-registry' and only works
    # within the cluster (i.e. browser-side retrieval won't work)
    SERVICE_HOST=$(env | grep DEVFILE_REGISTRY_SERVICE_HOST= | cut -d '=' -f 2)
    SERVICE_PORT=$(env | grep DEVFILE_REGISTRY_SERVICE_PORT= | cut -d '=' -f 2)
    URL="http://${SERVICE_HOST}:${SERVICE_PORT}"
    sed -i "s|{{ DEVFILE_REGISTRY_URL }}|${URL}|" "${devfiles[@]}" "${metas[@]}" "$INDEX_JSON"
  fi
fi

exec "${@}"
