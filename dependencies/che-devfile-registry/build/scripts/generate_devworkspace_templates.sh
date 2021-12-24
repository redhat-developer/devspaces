#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

set -e

# shellcheck disable=SC1091
source ./clone_and_zip.sh

npm install -g @eclipse-che/che-theia-devworkspace-handler@0.0.1-1640160609
mkdir -p /build/resources/v2/
for dir in /build/devfiles/*/
do
  devfile_url=$(grep "\"v2\":" "${dir}"meta.yaml) || :
  if [ -n "$devfile_url" ]; then
    devfile_url=${devfile_url##*\"v2\": \"}
    devfile_url=${devfile_url%/}
    devfile_url=${devfile_url%\"*}
    devfile_repo=${devfile_url%/tree*}
    name=$(basename "${devfile_repo}")

    npm_config_yes=true npx @eclipse-che/che-theia-devworkspace-handler --devfile-url:"${devfile_url}" \
    --editor:eclipse/che-theia/latest \
    --plugin-registry-url:https://crw-plugin-registry-main.surge.sh/v3/ \
    --output-file:"${dir}"devworkspace-che-theia-latest.yaml \
    "--project.${name}={{ DEVFILE_REGISTRY_URL }}/resources/v2/${name}.zip"
    clone_and_zip "${devfile_repo}" "${devfile_url##*/}" "/build/resources/v2/$name.zip"
  fi
done
