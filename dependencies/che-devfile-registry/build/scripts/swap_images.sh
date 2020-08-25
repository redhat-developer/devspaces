#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

# script common across operator-metadata, devfileregistry, and pluginregistry

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
YAML_ROOT="$1"

devfiles=$($SCRIPT_DIR/list_yaml.sh "$YAML_ROOT")

[[ "$(uname -m)" == "x86_64" ]] && exit 0

sed -E -i 's|eap-xp1-openjdk11-openshift-rhel8:.*|eap-xp1-openj9-11-openshift-rhel8:1.0|g' $devfiles
sed -E -i 's|plugin-java8-rhel8|plugin-java8-openj9-rhel8|g' $devfiles
sed -E -i 's|plugin-java11-rhel8|plugin-java11-openj9-rhel8|g' $devfiles
