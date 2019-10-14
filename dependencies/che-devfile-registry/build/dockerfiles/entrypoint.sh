#!/bin/bash
#
# Copyright (c) 2012-2018 Red Hat, Inc.
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
# Will execute any arguments on completion (`exec $@`)

set -e

REGISTRY=${CHE_DEVFILE_IMAGES_REGISTRY_URL}
ORGANIZATION=${CHE_DEVFILE_IMAGES_REGISTRY_ORGANIZATION}
TAG=${CHE_DEVFILE_IMAGES_REGISTRY_TAG}

DEFAULT_DEVFILES_DIR="/var/www/html/devfiles"
DEVFILES_DIR="${DEVFILES_DIR:-${DEFAULT_DEVFILES_DIR}}"

# Regex used to break an image reference into groups:
#   \1 - Whitespace and (optional) quotation preceding image reference
#   \2 - Registry portion of image, e.g. (quay.io)/eclipse/che-theia:tag
#   \3 - Organization portion of image, e.g. quay.io/(eclipse)/che-theia:tag
#   \4 - Image name portion of image, e.g. quay.io/eclipse/(che-theia):tag
#   \5 - Tag of image, e.g. quay.io/eclipse/che-theia:(tag)
#   \6 - Optional quotation following image reference
IMAGE_REGEX='([[:space:]]*"?)([._a-zA-Z0-9-]*)/([._a-zA-Z0-9-]*)/([._a-zA-Z0-9-]*):([._a-zA-Z0-9-]*)("?)'

# We can't use the `-d` option for readarray because
# registry.centos.org/centos/httpd-24-centos7 ships with Bash 4.2
# The below command will fail if any path contains whitespace
readarray -t devfiles < <(find "${DEVFILES_DIR}" -name 'devfile.yaml')
for devfile in "${devfiles[@]}"; do
  echo "Checking devfile $devfile"
  # Need to update each field separately in case they are not defined.
  # Defaults don't work because registry and tags may be different.
  if [ -n "$REGISTRY" ]; then
    echo "    Updating image registry to $REGISTRY"
    sed -i -E "s|image:$IMAGE_REGEX|image:\1${REGISTRY}/\3/\4:\5\6|" "$devfile"
  fi
  if [ -n "$ORGANIZATION" ]; then
    echo "    Updating image organization to $ORGANIZATION"
    sed -i -E "s|image:$IMAGE_REGEX|image:\1\2/${ORGANIZATION}/\4:\5\6|" "$devfile"
  fi
  if [ -n "$TAG" ]; then
    echo "    Updating image tag to $TAG"
    sed -i -E "s|image:$IMAGE_REGEX|image:\1\2/\3/\4:${TAG}\6|" "$devfile"
  fi
done

exec "${@}"
