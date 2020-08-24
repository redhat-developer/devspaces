#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

# script common across operator-metadata, devfileregistry, and pluginregistry

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
YAML_ROOT="$1"

readarray -d '' devfiles < <($SCRIPT_DIR/list_yaml.sh "$YAML_ROOT" | tr '\n' '\0')

if [[ "$(uname -m)" == "x86_64" ]] ; then
  exit 0
elif [[ "$(uname -m)" == "s390x" ]] ; then
  sed -E -i 's|(.*image: *"?).*jboss-eap-7-eap-xp1-openjdk11-openshift-rhel8[^"]*("?)|\1registry.redhat.io/jboss-eap-7/eap-xp1-openj9-11-openshift-rhel8:1.0\2|g' ${devfiles[@]}
  sed -E -i 's|(.*image: *"?).*jboss-eap-7-eap-xp1-openjdk8-openshift-rhel7:1.0[^"]*("?)|\1registry.redhat.io/jboss-eap-7/eap-xp1-openj9-11-openshift-rhel8:1.0\2|g' ${devfiles[@]}  # all plugins, not fuse
  sed -E -i 's|(.*value: *"?).*sso74-openshift-rhel8:7.4[^"]*("?)|\1registry.redhat.io/rh-sso-7/sso74-openj9-openshift-rhel8:7.4\2|g' ${devfiles[@]}
  sed -E -i 's|(.*image: *"?).*plugin-java11-rhel8[^"]*("?)|\1registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-plugin-java11-openj9-rhel8:2.4\2|g' ${devfiles[@]}
  sed -E -i 's|(.*image: *"?).*plugin-java8-rhel8[^"]*("?)|\1registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-plugin-java8-openj9-rhel8:2.4\2|g' ${devfiles[@]}
elif [[ "$(uname -m)" == "ppc64le" ]] ; then
  sed -E -i 's|(.*image: *"?).*jboss-eap-7-eap-xp1-openjdk11-openshift-rhel8[^"]*("?)|\1registry.redhat.io/jboss-eap-7/eap-xp1-openj9-11-openshift-rhel8:1.0\2|g' ${devfiles[@]}
  sed -E -i 's|(.*image: *"?).*jboss-eap-7-eap-xp1-openjdk8-openshift-rhel7:1.0[^"]*("?)|\1registry.redhat.io/jboss-eap-7/eap-xp1-openj9-11-openshift-rhel8:1.0\2|g' ${devfiles[@]}  # all plugins, not fuse
  sed -E -i 's|(.*value: *"?).*sso74-openshift-rhel8:7.4[^"]*("?)|\1registry.redhat.io/rh-sso-7/sso74-openj9-openshift-rhel8:7.4\2|g' ${devfiles[@]}
  sed -E -i 's|(.*image: *"?).*plugin-java11-rhel8[^"]*("?)|\1registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-plugin-java11-openj9-rhel8:2.4\2|g' ${devfiles[@]}
  sed -E -i 's|(.*image: *"?).*plugin-java8-rhel8[^"]*("?)|\1registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-plugin-java8-openj9-rhel8:2.4\2|g' ${devfiles[@]}
else
  echo "ERROR platfrom $(uname -m) not supported"
  exit 1
fi

exit 0
