#!/bin/bash
#
# Copyright (c) 2012-2018 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# Generated plugins index in JSON format.
# Arguments:
# 1 - plugin root folder, e.g. 'v3'

set -e

PLUGINS_DIR="/v3/plugins"

readarray -d '' metas < <(find "$1" -name 'meta.yaml' -print0)
# CI will complain since jq uses the same variable syntax as bash; we
# *don't* want variable substitution/expansion in the yq script.
# shellcheck disable=SC2016
yq -sS 'map(
    "\(.publisher)/\(.name)/\(.version)" as $id |
    {
        $id, displayName, version, type, name, description, publisher,
        links: {self: "\($PLUGINS_DIR)/\($id)"}
    } + if has("deprecate") then {deprecate} else null end ) |
    sort_by(.id)' "${metas[@]}" --arg "PLUGINS_DIR" "$PLUGINS_DIR"
