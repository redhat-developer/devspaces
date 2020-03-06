#!/bin/bash
#
# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

LOG_FILE="/tmp/image_digests.log"

function handle_error() {
  echo "  Could not read image metadata through skopeo inspect; skipping"
  echo -n "  Reason: "
  sed 's|^|    |g' $LOG_FILE
}

readarray -d '' devfiles < <(find "$1" -name 'devfile.yaml' -print0)
for image in $(yq -r '.components[]?.image' "${devfiles[@]}" | grep -v "null" | sort | uniq); do
  echo "Rewriting image $image"
  # Need to look before we leap in case image is not accessible
  if ! image_data=$(skopeo inspect "docker://${image}" 2>"$LOG_FILE"); then
    handle_error
    continue
  fi
  # Grab digest from image metadata json
  digest=$(echo "$image_data" | jq -r '.Digest')

  echo "  to use digest $digest"
  digest_image="${image%:*}@${digest}"

  # Rewrite images to use sha-256 digests
  sed -i -E 's|"?'"${image}"'"?|"'"${digest_image}"'" # tag: '"${image}"'|g' "${devfiles[@]}"
done
rm $LOG_FILE
