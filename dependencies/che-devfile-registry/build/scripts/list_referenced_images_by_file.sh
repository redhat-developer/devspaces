#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# List all images referenced in devfile.yaml files, and define which devfile is to blame
#

set -e

CONTAINERS=""

while IFS= read -r -d '' file; do
  # shellcheck disable=SC2086 disable=SC2002
  URL=$(cat ${file/\/devworkspace*.yaml/\/meta.yaml} | yq -r '.links.v2')
  CONTAINERS="${CONTAINERS} $(yq -r '..|.image?' "${file}" | grep -v "null" | sort -u | sed -r -e "s#\$#!${URL}/devfile.yaml!${file##*/}#g")"
done < <(find "$1" \( -name 'devworkspace-*.yaml' \) -print0)

CONTAINERS_UNIQ=()
# shellcheck disable=SC2199
for c in $CONTAINERS; do if [[ ! "${CONTAINERS_UNIQ[@]}" =~ ${c} ]]; then CONTAINERS_UNIQ+=("$c"); fi; done
# shellcheck disable=SC2207
IFS=$'\n' CONTAINERS=($(sort <<<"${CONTAINERS_UNIQ[*]}")); unset IFS

for c in "${CONTAINERS[@]}"; do
  echo "${c}" | tr "!" "\t"
done
