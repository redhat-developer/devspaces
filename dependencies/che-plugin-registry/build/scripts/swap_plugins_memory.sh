#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

# increase memory allocation for theia pods for ppc64le only - https://issues.redhat.com/browse/CRW-1475

FORCE_SWAP=0
arch="$(uname -m)"

while [[ "$#" -gt 0 ]]; do
  case $1 in
  '-f') FORCE_SWAP=1;; # force transformation even on an incompatible architecture for testing purposes
  '-a') arch="$2"; shift 1;;
  *) YAML_ROOT="$1";;
  esac
  shift 1
done

replaceField()
{
  yamlFile="$1"
  updateName="$2"
  updateVal="$3"
  # echo -n "Before: "; yq -r ${updateName} "${yamlFile}"
  # shellcheck disable=SC2086,SC2016
  yq -Y --arg updateName "${updateName}" --arg updateVal "${updateVal}" ${updateName}' = $updateVal' ${yamlFile} > ${yamlFile}.2
  if [ -s "${yamlFile}".2 ]; then
    mv "${yamlFile}".2 "${yamlFile}"
    echo -n "[INFO] $1 updated: "
    # shellcheck disable=SC2086
    yq -r ${updateName} "${yamlFile}"
  else
    rm -f "${yamlFile}".2
    echo -n "[ERROR] Could not change field $2 in $1: "
    # shellcheck disable=SC2086
    yq -r ${updateName} "${yamlFile}"
    exit 1
  fi
}

if [[ "$arch" == "ppc64le" ]] || [[ $FORCE_SWAP -eq 1 ]]; then
    echo -n "[INFO] swap plugins memory requirements on $arch"
    if [[ $FORCE_SWAP -eq 1 ]]; then echo -n " (forced)"; fi
    echo
   replaceField "$YAML_ROOT"/plugins/eclipse/che-theia/latest/meta.yaml '.spec.containers[].memoryLimit' "2Gi" # CRW-1475
   replaceField "$YAML_ROOT"/plugins/redhat/vscode-camelk/latest/meta.yaml '.spec.containers[].memoryLimit' "1.5Gi" # CRW-1633
   replaceField "$YAML_ROOT"/plugins/redhat/vscode-openshift-connector/latest/meta.yaml '.spec.containers[].memoryLimit' "2.5Gi" # CRW-1634
   replaceField "$YAML_ROOT"/plugins/ms-python/python/latest/meta.yaml '.spec.containers[].memoryLimit' "1Gi" # CRW-1635
else
    echo "[INFO] nothing to do on $arch; only swap plugins memory requirements on ppc64le arch"
fi
