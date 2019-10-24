#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Utility for automatically generating latest meta.yamls for plugins.
#

set -e

for plugin_dir in v3/plugins/*/*; do
  echo "Updating plugin ${plugin_dir}"
  # Make sure every plugin has a 'latest.version' file
  if [ ! -f "${plugin_dir}"/latest.txt ]; then
    echo "    Missing latest.txt: ${plugin_dir}/latest.txt"
    exit 1
  fi
  # Generate meta.yaml for latest version
  version=$(cat "${plugin_dir}/latest.txt")
  latest_meta="${plugin_dir}/${version}/meta.yaml"
  if [ ! -f "${latest_meta}" ]; then
    echo "    [ERROR]: version.latest specifies '$version' but no such meta.yaml is found"
    echo "             expecting: '${plugin_dir}/${version}/meta.yaml'"
  fi
  echo "    Found latest meta ${plugin_dir}/${version}/meta.yaml"
  mkdir -p "${plugin_dir}/latest"
  yq -y '. + {version: "latest"}' "$latest_meta" > "${plugin_dir}/latest/meta.yaml"
done
