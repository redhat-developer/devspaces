#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# Prints plugin/editor full ID to STDOUT in format 'publisher_id/plugin_id/version'.
# Supports old and new notation.
# Arguments:
#   1 - path to meta.yaml
function evaluate_plugin_id() {
    # yq command to do the same; not used as it is much slower.
    # yq -r '"\(.publisher)/\(.name)/\(.version)"' $1
    name_field=$(sed -nr 's|^name: ([-.0-9A-Za-z]+)|\1|p' "$1")
    version_field=$(sed -nr 's|^version: ([-.0-9A-Za-z]+)|\1|p' "$1")
    publisher_field=$(sed -nr 's|^publisher: ([-.0-9A-Za-z]+)|\1|p' "$1")
    echo "${publisher_field}/${name_field}/${version_field}"
}
