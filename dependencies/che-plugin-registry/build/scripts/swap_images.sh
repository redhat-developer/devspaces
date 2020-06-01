#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

# script common across operator-metadata, devfileregistry, and pluginregistry

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
YAML_ROOT="$1"

if [[ "$(uname -m)" == "x86_64" ]] ; then
  exit 0
fi

readarray -d '' devfiles < <($SCRIPT_DIR/list_yaml.sh "$YAML_ROOT" | tr '\n' '\0')
sed -E -i 's|(.*image: *"?).*jboss-eap-7-eap-xp1-openjdk11-openshift-rhel8[^"]*("?)|\1registry-proxy.engineering.redhat.com/rh-osbs/jboss-eap-7-eap73-openj9-11-openshift-rhel8:7.3.0\2|g' ${devfiles[@]}
sed -E -i 's|(.*image: *"?).*jboss-eap-7-eap-xp1-openjdk8-openshift-rhel7:1.0[^"]*("?)|\1registry-proxy.engineering.redhat.com/rh-osbs/jboss-eap-7-eap73-openj9-11-openshift-rhel8:7.3.0\2|g' ${devfiles[@]}  # all plugins, not fuse
sed -E -i 's|(.*value: *"?).*sso74-openshift-rhel8:7.4[^"]*("?)|\1registry-proxy.engineering.redhat.com/rh-osbs/sso74-openj9-openshift-rhel8:7.4\2|g' ${devfiles[@]}
