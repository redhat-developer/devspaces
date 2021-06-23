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
  local tag="$(echo "$image_url" | cut -d ':' -f 2)"
  if [[ ! -z "$($SCRIPT_DIR/find_image.sh "${image_url%:*}" x86_64 2> /dev/null | jq -r '.Digest')" ]] ; then
    if [[ "$ARCH" == "x86_64" ]] ; then
      echo "[WARN] Image $image_url version not found: remove $yaml_file from registry."
    else
      echo "[WARN] Image $image_url not found for architecture $ARCH: remove $yaml_file from registry."
    fi
  elif [[ ! -z $(echo $image_url | grep 'openj9') ]] && (( $(echo "$tag" | awk '{ print ($1 < 2.4)}') )) ; then
    # special case for older plugins: https://issues.redhat.com/browse/CRW-1193
    # openj9 containers don't exist on x and versions below 2.4 will never exist.  do not raise error
    echo "[WARN] Image $image_url version not found: remove $yaml_file from registry."
  else
    echo "[ERROR] Could not read image metadata through skopeo inspect --tls-verify=false; skip $image_url"
    echo -n "  Reason: "
    sed 's|^|    |g' $LOG_FILE
    exit 1
  fi
  for f in $(ls `dirname $yaml_file`/*.yaml) ; do
    mv "$f" "$f.removed"
  done
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
