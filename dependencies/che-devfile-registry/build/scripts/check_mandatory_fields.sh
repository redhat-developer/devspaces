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

FIELDS=('displayName' 'description' 'tags' 'icon' 'globalMemoryLimit')

readarray -d '' metas < <(find devfiles -name 'meta.yaml' -print0)
for meta in "${metas[@]}"; do
    echo "Checking devfile '${meta}'"
    unset NULL_OR_EMPTY_FIELDS
    for field in "${FIELDS[@]}"; do
        if ! grep -q "^${field}:.*\S" "$meta"; then
            NULL_OR_EMPTY_FIELDS+="$field "
        fi
    done
    if [[ -n "${NULL_OR_EMPTY_FIELDS}" ]];then
        echo "!!!   Null or empty mandatory fields in ${meta}: $NULL_OR_EMPTY_FIELDS"
        INVALID_FIELDS=true
    fi
done

if [[ -n "${INVALID_FIELDS}" ]];then
    exit 1
fi
