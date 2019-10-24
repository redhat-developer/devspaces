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
  # Make sure every plugin has a 'latest.version' file
  if [ ! -f "${plugin_dir}"/latest.txt ]; then
    echo "    Missing latest.txt: ${plugin_dir}/latest.txt"
    exit 1
  fi
  version=$(cat "${plugin_dir}/latest.txt")
  readarray -d '' to_remove < <(find "${plugin_dir}" -mindepth 1 -type d -not -name "$version" -print0)
  if [ ${#to_remove[@]} != 0 ]; then
    echo "Plugin ${plugin_dir}: found latest ${version} - removing non-latest versions:"
    printf '    %s\n' "${to_remove[@]}"
    rm -rf "${to_remove[@]}"
  fi
done
