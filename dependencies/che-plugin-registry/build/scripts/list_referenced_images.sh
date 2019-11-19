#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# List all images referenced in meta.yaml files
#

set -e

readarray -d '' metas < <(find "$1" -name 'meta.yaml' -print0)
yq -r '..|.image?' "${metas[@]}" | grep -v 'null' | sort | uniq
