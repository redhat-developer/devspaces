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

PRECACHED_ROOT_DIR_NAME="result"


# if archive with prebuilt extensions is located at given path,
# use them to substitute
if [ -f "/tmp/vsix.tar.gz" ]; then
echo 'found non empty extensions tar, unpacking'
  tar -zxvf /tmp/vsix.tar.gz
  readarray -d '' precached_plugins < <(find $PRECACHED_ROOT_DIR_NAME -name '*.vsix' -print0)
fi

mkdir -p "${RESOURCES_DIR}" "${TEMP_DIR}"
for extension in $(yq -r '.spec.extensions[]?' "${metas[@]}" | sort | uniq); do
  echo -en "Caching extension ${extension}\n    "
  # Workaround for getting filenames through content-disposition: copy to temp
  # dir and read filename before moving to /resources.


  # Before attempting to download, check if we already have this file in supplied precached archive
  # if found, skip the download
  for plugin_file_path in "${precached_plugins[@]}"; do
    echo evaluating $plugin_file_path

    # strip root directory from path on filesystem to match it with extension URL
    plugin_file_path=${plugin_file_path#${PRECACHED_ROOT_DIR_NAME}/}
    plugin_file_path=${plugin_file_path%/*.vsix}

    echo directorey: "$plugin_file_path"

  #  if [[ $precached_url == */vspackage ]]; then
  #    precached_url=${precached_url%/vspackage}
  #    echo --- transformed to "$precached_url"
  #  fi
    if [[ $plugin_file_path == $precached_url ]]; then
      echo mached extension "$plugin_file_path" and "$precached_url"
      matched_plugin_path = plugin_file_path
      break
    else
      echo not mached extension "$plugin_file_path" and "$precached_url"
    fi
  done

  if [[ -z matched_plugin_path ]]; then
    echo "omitting download of plugin ${matched_plugin_path}"
    mv "${matched_plugin_path}"  ${TEMP_DIR}
  else
    wget -P "${TEMP_DIR}" -nv --content-disposition "${extension}"
  fi

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
