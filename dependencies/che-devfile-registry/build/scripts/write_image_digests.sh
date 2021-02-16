#!/bin/bash
#
# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
LOG_FILE="/tmp/image_digests.log"

function handle_error() {
  the_image="$1"
  echo "  Could not read image metadata through skopeo inspect; skip $the_image"
  echo -n "  Reason: "
  sed 's|^|    |g' $LOG_FILE
}

readarray -d '' devfiles < <(find "$1" -name 'devfile.yaml' -print0)
for image in $(yq -r '.components[]?.image' "${devfiles[@]}" | grep -v "null" | sort | uniq); do
  digest="$(skopeo inspect "docker://${image}" 2>"$LOG_FILE" | jq -r '.Digest')"
  if [[ ${digest} ]]; then
    echo "    $digest # ${image}"
  else 
    # for other build methods or for falling back to other registries when not found, can apply transforms here
    if [[ -x "${SCRIPT_DIR}/write_image_digests_alternate_urls.sh" ]]; then
      # since extension file may not exist, disable this check
      # shellcheck disable=SC1090
      source "${SCRIPT_DIR}/write_image_digests_alternate_urls.sh"
    fi
  fi

  # don't rewrite if we couldn't get a digest from either the basic image or the alternative image
  if [[ ! ${digest} ]]; then
    handle_error "$image"
    continue
  fi

  digest_image="${image%:*}@${digest}"

  # Rewrite images to use sha-256 digests
  sed -i -E 's|"?'"${image}"'"?|"'"${digest_image}"'" # tag: '"${image}"'|g' "${devfiles[@]}"
done
rm $LOG_FILE
