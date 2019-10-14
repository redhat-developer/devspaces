#!/bin/bash
#
# Copyright (c) 2012-2018 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# Download referenced extension artifacts to <plugin root>/resources
# Arguments:
# 1 - plugin root folder, e.g. 'v3'

set -e

if [[ $2 == "--latest-only" ]]; then
  readarray -d '' metas < <(find "$1" -name 'meta.yaml' | grep "/latest/" | tr "\r\n" "\0")
else
  readarray -d '' metas < <(find "$1" -name 'meta.yaml' -print0)
fi

RESOURCES_DIR="${1}/resources/"
TEMP_DIR="${1}/extensions_temp/"

mkdir -p "${RESOURCES_DIR}" "${TEMP_DIR}"
for extension in $(yq -r '.spec.extensions[]?' "${metas[@]}" | sort | uniq); do
  echo -en "Caching extension ${extension}\n    "
  # Workaround for getting filenames through content-disposition: copy to temp
  # dir and read filename before moving to /resources.
  wget -P "${TEMP_DIR}" -nv --content-disposition "${extension}"
  file=$(find "${TEMP_DIR}" -type f)
  filename=$(basename "${file}")

  # Strip protocol and filename from URL
  target_dir=${extension#*//}
  target_dir=${target_dir%/*}
  mkdir -p "${RESOURCES_DIR%/}/${target_dir}"

  destination="${target_dir%/}/${filename}"
  if [ -f "${RESOURCES_DIR%/}/${destination}" ]; then
    echo "    Encoutered duplicate file: ${RESOURCES_DIR%/}/${destination}"
    echo "    while processing ${extension}"
    exit 1
  fi

  # echo "    Caching ${filename} to ${RESOURCES_DIR%/}/${destination}"
  mv "${file}" "${RESOURCES_DIR%/}/${destination}"

  echo "    Rewriting meta.yaml '${extension}' -> 'relative:extension/resources/${destination#/}''"
  sed -i "s|${extension}|relative:extension/resources/${destination#/}|" "${metas[@]}"
done

rm -rf "${TEMP_DIR}"
