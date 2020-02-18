#!/bin/bash
#
# Copyright (c) 2019-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#


readarray -d '' metas < <(find "$1" -name 'meta.yaml' -print0)
for image in $(yq -r '.spec | .containers[]?,.initContainers[]? | .image' "${metas[@]}" | sort | uniq); do
  echo "Rewriting image $image"
  digest=$(skopeo inspect "docker://${image}" | jq -r '.Digest')
  echo "  to use digest $digest"
  digest_image="${image%:*}@${digest}"

  # Rewrite images to use sha-256 digests
  sed -i -E 's|"?'"${image}"'"?|"'"${digest_image}"'" # tag: '"${image}"'|g' "${metas[@]}"
done
