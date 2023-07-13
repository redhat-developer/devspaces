#!/bin/bash
#
# Copyright (c) 2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Arguments
#    $1 - the new plugin registry image
#

set -e -u

IMAGE=$1
CHECLUSTER_NAME="$(kubectl get checluster --all-namespaces -o json | jq -r '.items[0].metadata.name')"
CHECLUSTER_NAMESPACE="$(kubectl get checluster --all-namespaces -o json | jq -r '.items[0].metadata.namespace')"

TMPDIR="$(mktemp -d)"
trap 'rm -rf -- "$TMPDIR"' EXIT
cat << EOF > "${TMPDIR}"/patch-file.yaml
spec:
  components:
    pluginRegistry:
      deployment:
        containers:
          - name: plugin-registry
            image: ${IMAGE}
EOF

echo "Patching CheCluster ${CHECLUSTER_NAME} in namespace ${CHECLUSTER_NAMESPACE} to use ${IMAGE} as plugin registry image."
echo
echo "Original CheCluster .spec.components.pluginRegistry:"
kubectl get  -n "${CHECLUSTER_NAMESPACE}" checluster "${CHECLUSTER_NAME}" -o json | jq '.spec.components.pluginRegistry' 
echo
echo "Patch file:"
cat "${TMPDIR}"/patch-file.yaml
echo
kubectl patch -n "${CHECLUSTER_NAMESPACE}" checluster "${CHECLUSTER_NAME}" --type merge --patch "$(cat "${TMPDIR}"/patch-file.yaml)"
echo
echo "Patched CheCluster .spec.components.pluginRegistry:"
kubectl get -n "${CHECLUSTER_NAMESPACE}" checluster "${CHECLUSTER_NAME}" -o json | jq '.spec.components.pluginRegistry'
