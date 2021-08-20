#!/bin/bash
#
# Copyright (c) 2020-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

# script common to devfileregistry and pluginregistry; see also crw-operator/build/scripts/swap_images.sh

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
YAML_ROOT="$1"

devfiles=$("$SCRIPT_DIR"/list_yaml.sh "$YAML_ROOT")

# Note: optional -f flag will force this transformation even on an incompatible architecture,
# so we can call this script from crw-operator/build/scripts/insert-related-images-to-csv.sh
# shellcheck disable=SC2086
if [[ "$(uname -m)" != "x86_64" ]] || [[ "$2" == "-f" ]]; then
    sed -E -i 's|plugin-java8-rhel8|plugin-java8-openj9-rhel8|g' $devfiles
    sed -E -i 's|plugin-java11-rhel8|plugin-java11-openj9-rhel8|g' $devfiles
    sed -E -i 's|eap-xp2-openjdk11-openshift-rhel8:.*|eap-xp2-openj9-11-openshift-rhel8:2.0|g' $devfiles
    sed -E -i 's|eap-xp3-openjdk11-openshift-rhel8:.*|eap-xp3-openj9-11-openshift-rhel8:3.0|g' $devfiles
else
    echo "[INFO] nothing to do on $(uname -m); only swap openjdk for openj9 images on s390x and ppc64le arches"
fi
