#!/bin/bash
#
# Copyright (c) 2018-2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Utility for copying latest meta.yamls into 'latest' directory for each plugin
# to allow plugins to be specified with version 'latest'

set -e

# Copies the meta.yaml corresponding to the newest version into
# 'latest' folder for plugin. If that plugin contains a folder named 'next',
# this overrides all other versions. If the plugin contains a folder named
# 'latest', nothing is done.
#
# Takes one parameter: the relative path to a specific publisher/name
# (e.g. v3/plugins/redhat/java)
function create_latest_dir() {
  path=$1

  # Create latest dir if it does not exist
  mkdir -p "$path"/latest

  # Get version of plugin with latest 'firstPublishedDate'
  mapfile -t metas < <(find "${path}" -path "${path}"/latest -prune -o -name 'meta.yaml' -print)
  latest_ver=$(yq -s -r 'max_by(.firstPublicationDate | strptime("%Y-%m-%d") | mktime) | .version' "${metas[@]}")

  # Rewrite version in latest meta.yaml to be 'latest'
  latest_meta=$(yq '.version = "latest"' "${path}"/"${latest_ver}"/meta.yaml)

  # Compare this new latest.meta with current latest, if it exists.
  if [ ! -f "${path}"/latest/meta.yaml ]; then
    echo "${latest_meta}" | yq -y '.' > "${path}"/latest/meta.yaml
    echo "  Added latest meta.yaml from " "${path}"/"${latest_ver}"/meta.yaml
  else
    if ! diff <(yq -S '.' "${path}"/latest/meta.yaml) <(echo "${latest_meta}" | yq -S '.') > /dev/null; then
      echo "  WARN: Found newer meta.yaml in " "${path}"/"${latest_ver}"/meta.yaml
      echo "        No changes are made, but ensure the correct version is in 'latest'"
    else
      echo "  No changes required"
    fi
  fi
}

for d in v3/plugins/*/*; do
  echo "Working on directory: $d"
  create_latest_dir "$d"
done
