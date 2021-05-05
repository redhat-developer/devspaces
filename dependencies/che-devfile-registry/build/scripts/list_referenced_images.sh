#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# List all images referenced in devfile.yaml files
#

set -e

CONTAINERS=""

while IFS= read -r -d '' file; do
  CONTAINERS="${CONTAINERS} $(yq -r '..|.image?' "${file}" | grep -v "null" | sort | uniq)"
done < <(find "$1" -name 'devfile.yaml' -print0)

CONTAINERS_UNIQ=()
# shellcheck disable=SC2199
for c in $CONTAINERS; do if [[ ! "${CONTAINERS_UNIQ[@]}" =~ ${c} ]]; then CONTAINERS_UNIQ+=("$c"); fi; done
# shellcheck disable=SC2207
IFS=$'\n' CONTAINERS=($(sort <<<"${CONTAINERS_UNIQ[*]}")); unset IFS

for c in "${CONTAINERS[@]}"; do
  echo "$c"
done
