#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
# script invoked for pluginregistry to bump memory for theia on power only - https://issues.redhat.com/browse/CRW-1475

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
YAML_ROOT="$1"

metayaml=$($SCRIPT_DIR/list_yaml.sh "$YAML_ROOT"/plugins/eclipse/che-theia/next)

# we bump up memory for che-theia's meta.yaml only for power 
if [[ "$(uname -m)" == "ppc64le" ]]; then
   sed -E -i 's|memoryLimit: "512M"|memoryLimit: "2Gi"|g' $metayaml
fi

