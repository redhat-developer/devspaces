#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
set -e

readarray -d '' metas < <(find "$1" -name 'meta.yaml' -print0)
for meta in "${metas[@]}"; do
    DATE=$(date -I)
    if ! grep -q '^firstPublicationDate:.*\S' "$meta"; then
      sed -i "$ a firstPublicationDate: \"${DATE}\"" "$meta"
    fi

    sed -i "$ a latestUpdateDate: \"${DATE}\"" "$meta"
done
