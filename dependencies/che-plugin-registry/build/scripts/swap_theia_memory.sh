#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

# increase memory allocation for theia pods for ppc64le only - https://issues.redhat.com/browse/CRW-1475

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
YAML_ROOT="$1"

metayamls="$($SCRIPT_DIR/list_yaml.sh "$YAML_ROOT"/plugins/eclipse/che-theia)"

replaceField()
{
  yamlFile="$1"
  updateName="$2"
  updateVal="$3"
  yq -Y --arg updateName "${updateName}" --arg updateVal "${updateVal}" ${updateName}' = $updateVal' ${yamlFile} > ${yamlFile}.2
  mv ${yamlFile}.2 ${yamlFile}
}

# Note: optional -f flag will force this transformation even on an incompatible architecture for testing purposes
if [[ "$(uname -m)" == "ppc64le" ]] || [[ "$2" == "-f" ]]; then 
   for metayaml in $metayamls; do
      replaceField $metayaml '.spec.containers[].memoryLimit' "2Gi"
   done
fi
