#!/bin/bash
#
# Copyright (c) 2018-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Arguments
#    $1 - devfiles directory
#    $2 - resources directory, where project zips will be stored.
#
# Only supports downloading projecst from GitHub.

set -e

DEVFILES_DIR="${1%/}"
INDEX_JSON="${DEVFILES_DIR#./}/index.json"
RESOURCES_DIR="${2%/}/images/"
RESOURCES_DIR="${RESOURCES_DIR#\./}"
TEMP_DIR="${RESOURCES_DIR%/}/temp_images"

readarray -d '' metas < <(find "${DEVFILES_DIR#./}" -name 'meta.yaml' -print0)

images=$(yq -S -r '.icon' "${metas[@]}" | sort | uniq)
mkdir -p "$RESOURCES_DIR" "$TEMP_DIR"

echo "Caching images referenced in devfiles"
while read -r image; do
  if [[ ! "$image" == http* ]]; then
    continue
  fi
  # Workaround for getting filenames through content-disposition: copy to temp
  # dir and read filename before moving to /resources.
  wget -P "${TEMP_DIR}" -nv --content-disposition "${image}"
  file=$(find "${TEMP_DIR}" -type f)
  filename=$(basename "${file}")

  # Store downloaded image in resources dir, on subpath derived from URL (strip
  # protocol and last portion)
  image_dir="${image#*//}"
  image_dir="${RESOURCES_DIR%/}/${image_dir%/*}"
  mkdir -p "$image_dir"

  # Strip query and fragment components from image URL
  cached_image="${image_dir%/}/${filename%%\?*}"
  cached_image="${cached_image%%\#*}"
  mv "$file" "$cached_image"
  echo "  Downloaded image $image to $cached_image"

  cached_url="{{ DEVFILE_REGISTRY_URL }}/${cached_image#/}"
  sed -i "s|${image}|${cached_url}|g" "${metas[@]}" "$INDEX_JSON"
  echo "  Updated devfiles to point at cached image"
done <<< "$images"

rm -rf "$TEMP_DIR"
