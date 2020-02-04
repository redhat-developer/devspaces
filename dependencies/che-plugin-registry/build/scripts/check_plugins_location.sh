#!/bin/bash
#
# Copyright (c) 2018-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# Checks that plugin files are located at the expected path.
# Arguments:
# 1 - plugin root folder, e.g. 'v3'

set -e

# shellcheck source=./build/scripts/util.sh
source "$(dirname "$0")/util.sh"

readarray -d '' metas < <(find "$1" -name 'meta.yaml' -print0)
for meta in "${metas[@]}"; do
    plugin_id=$(evaluate_plugin_id "$meta")
    expected_path="$1/plugins/${plugin_id}/meta.yaml"
    if [[ "${expected_path}" != "${meta}" ]]; then
      echo "!!! Location mismatch in plugin '${plugin_id}':"
      echo "!!!   Expected location: '${expected_path}'"
      echo "!!!   Actual location: '${meta}' "
      FOUND=true
    fi
done

if [[ $FOUND ]];then
  exit 1
fi
