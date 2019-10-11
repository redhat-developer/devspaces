#!/bin/bash
#
# Copyright (c) 2018-2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Utility for checking that every plugin in v3 has a 'latest' directory.
#

set -e

for plugin_dir in v3/plugins/*/*; do
  if [ ! -d "${plugin_dir}"/latest ] || [ ! -f "${plugin_dir}"/latest/meta.yaml ]; then
    echo -e "\tMissing meta.yaml: ${plugin_dir}/latest/meta.yaml"
    MISSING=true
  fi
done

if [[ $MISSING ]]; then
  exit 1
fi
