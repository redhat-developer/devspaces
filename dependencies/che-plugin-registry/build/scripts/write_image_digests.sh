#!/bin/bash
#
# Copyright (c) 2019-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

LOG_FILE="/tmp/image_digests.log"

function handle_error() {
  the_image="$1"
  # NOTE: need --tls-verify=false to bypass SSL/TLD Cert validation errors - https://github.com/nmasse-itix/OpenShift-Examples/blob/master/Using-Skopeo/README.md#ssltls-issues
  echo "  Could not read image metadata through skopeo --tls-verify=false inspect; skip $the_image"
  echo -n "  Reason: "
  sed 's|^|    |g' $LOG_FILE
}

readarray -d '' metas < <(find "$1" -name 'meta.yaml' -print0)
for image in $(yq -r '.spec | .containers[]?,.initContainers[]? | .image' "${metas[@]}" | sort | uniq); do
  digest="$(skopeo --tls-verify=false inspect "docker://${image}" 2>"$LOG_FILE" | jq -r '.Digest')"
  if [[ ${digest} ]]; then
    echo "    $digest # ${image}"
  else 
    # for other build methods or for falling back to other registries when not found, can apply transforms here
    if [[ -x "$(dirname "$0")/write_image_digests_alternate_urls.sh" ]]; then
      # since extension file may not exist, disable this check
      # shellcheck disable=SC1090,SC1091
      source "$(dirname "$0")/write_image_digests_alternate_urls.sh"
    fi
  fi

  # don't rewrite if we couldn't get a digest from either the basic image or the alternative image
  if [[ ! ${digest} ]]; then
    handle_error "$image"
    continue
  fi

  digest_image="${image%:*}@${digest}"

  # Rewrite images to use sha-256 digests
  sed -i -E 's|"?'"${image}"'"?|"'"${digest_image}"'" # tag: '"${image}"'|g' "${metas[@]}"
done
rm $LOG_FILE
