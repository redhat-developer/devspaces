#!/bin/bash
#
# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
set +x
SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
YAML_ROOT="$1"
[[ -z "$2" ]] && ARCH=$(uname -m) || ARCH="$2"
[[ $ARCH == "x86_64" ]] && ARCH="amd64"
LOG_FILE="$(mktemp)" && trap "rm -f $LOG_FILE" EXIT

function handle_error() {
  local yaml_file="$1"
  local image_url="$2"
  if [[ -z "$(tail -1 $LOG_FILE | grep -v "no image found in manifest list for architecture $ARCH")" ]] ; then
    echo "[WARN] Image $image_url not found for architecture $ARCH: remove $yaml_file from registry."
    mv "$yaml_file" "$yaml_file.removed"
  elif [[ ! -z "$($SCRIPT_DIR/find_image.sh "${image_url%:*}" $ARCH | jq -r '.Digest')" ]] ; then
    echo "[WARN] Image $image_url not found (404): remove $yaml_file from registry."
    mv "$yaml_file" "$yaml_file.removed"
  elif [[ $(egrep "manifest unknown|Error reading manifest" ${LOG_FILE}) ]]; then
    echo "[WARN] Manifest for $image_url not found: remove $yaml_file from registry."
    mv "$yaml_file" "$yaml_file.removed"
  else
    echo "[ERROR] Could not read image metadata through skopeo inspect --tls-verify=false; skip $image_url"
    echo "[ERROR] Remove $yaml_file from registry."
    echo -n "  Reason: "
    sed 's|^|    |g' $LOG_FILE
    mv "$yaml_file" "$yaml_file.removed"
    exit 1
  fi
}

for image_url in $($SCRIPT_DIR/list_referenced_images.sh "$YAML_ROOT") ; do
  digest=$($SCRIPT_DIR/find_image.sh "$image_url" $ARCH  2> $LOG_FILE | jq -r '.Digest')
  for yaml_file in $($SCRIPT_DIR/list_yaml.sh "$YAML_ROOT") ; do
    [[ -z "$($SCRIPT_DIR/list_referenced_images.sh "$yaml_file" | grep $image_url)" ]] && continue 
    if [[ -z "$digest" ]] ; then
      handle_error "$yaml_file" "$image_url"
    else
      # Rewrite image to use sha-256 digests
      digest_image="${image_url%:*}@${digest}"
      sed -i -E 's|"?'"${image_url}"'"?|"'"${digest_image}"'" # tag: '"${image_url}"'|g' "$yaml_file"
       echo "[INFO] Update $yaml_file with $digest_image"
    fi
  done
done
