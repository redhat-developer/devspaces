#!/bin/bash
#
# Copyright (c) 2018-2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

# Checks whether mandatory fields are in place. Also checks value of 'category' field.

set -e

# shellcheck source=./build/scripts/util.sh
source "$(dirname "$0")/util.sh"

readarray -d '' metas < <(find "$1" -name 'meta.yaml' -print0)

for meta in "${metas[@]}"; do
  plugin_id=$(evaluate_plugin_id "$meta")
  echo "Checking plugin '${plugin_id}'"

  if ! jsonschema ./meta.yaml.schema -F $'\t{error.message}\n' -i <(yq . "${meta}"); then
    INVALID_JSON=true
  fi
done

if [[ $INVALID_JSON ]]; then
  exit 1
fi