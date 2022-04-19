#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

set -e

readarray -d '' metas < <(find devfiles -name 'meta.yaml' -print0 | sort -z)
for meta in "${metas[@]}"; do
    META_DIR=$(dirname "${meta}")
    # Workaround to include self-links, since it's not possible to
    # get filename in yq easily
    # Extra links may already be there, so just update with self link

    # Ignore double quotes warning for yq expression
    # shellcheck disable=SC2016,SC2094
    cat <<< "$(yq -y --arg metadir "${META_DIR}" '.links |= . + {self: "/\($metadir)/devfile.yaml" }' "${meta}")"  > "${meta}"
    if [ "$(yq '.links.v2' "${meta}")" != "null" ]; then
      # Ignore double quotes warning for yq expression
      # shellcheck disable=SC2016,SC2094
      cat <<< "$(yq -y --arg metadir "${META_DIR}" '.links.devWorkspaces |= . +
      {"eclipse/che-theia/latest": "/\($metadir)/devworkspace-che-theia-latest.yaml"}' "${meta}")" > "${meta}"
    fi
done
yq -s 'map(.)' "${metas[@]}"
