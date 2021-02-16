#!/bin/bash
#
# Copyright (c) 2018-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

set -e

readarray -d '' metas < <(find devfiles -name 'meta.yaml' -print0)
for meta in "${metas[@]}"; do
    META_DIR=$(dirname "${meta}")
    # Workaround to include self-links, since it's not possible to
    # get filename in yq easily
    echo -e "links:\n  self: /${META_DIR}/devfile.yaml" >> "${meta}"
done
yq -s 'map(.)' "${metas[@]}"
