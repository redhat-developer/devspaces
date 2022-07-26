#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

set -e

# shellcheck disable=SC1091
source ./build/scripts/clone_and_zip.sh
VERSION=$(cat ../VERSION)
arch="$(uname -m)"

# Install che-theia-devworkspace-handler
theia_devworkspace_handler="che-theia-devworkspace-handler"
npm install -g @eclipse-che/"${theia_devworkspace_handler}"@"$(jq -r --arg v $theia_devworkspace_handler '.[$v]' versions.json)"
# Install che-code-devworkspace-handler
code_devworkspace_handler="che-code-devworkspace-handler"
npm install -g @eclipse-che/"${code_devworkspace_handler}"@"$(jq -r --arg v $code_devworkspace_handler '.[$v]' versions.json)"

mkdir -p ./resources/v2/
for dir in ./devfiles/*/
do
  devfile_url=$(grep "v2:" "${dir}"meta.yaml) || :
  if [ -n "$devfile_url" ]; then
    devfile_url=${devfile_url##*v2: }
    devfile_url=${devfile_url%/}
    devfile_url=${devfile_url%\"*}
    devfile_repo=${devfile_url%/tree*}
    name=$(basename "${devfile_repo}")

    # Generate devworkspace-che-theia-latest.yaml  
    npm_config_yes=true npx @eclipse-che/${theia_devworkspace_handler} --devfile-url:"${devfile_url}" \
    --editor:eclipse/che-theia/latest \
    --plugin-registry-url:https://redhat-developer.github.io/devspaces/che-plugin-registry/"${VERSION}"/"${arch}"/v3 \
    --output-file:"${dir}"devworkspace-che-theia-latest.yaml \
    "--project.${name}={{INTERNAL_URL}}/resources/v2/${name}.zip"

    # Generate devworkspace-che-code-insiders.yaml
    npm_config_yes=true npx @eclipse-che/${code_devworkspace_handler} --devfile-url:"${devfile_url}" \
    --editor-entry:che-incubator/che-code/insiders \
    --plugin-registry-url:https://redhat-developer.github.io/devspaces/che-plugin-registry/"${VERSION}"/"${arch}"/v3 \
    --output-file:"${dir}"devworkspace-che-code-insiders.yaml \
    "--project.${name}={{INTERNAL_URL}}/resources/v2/${name}.zip"

    clone_and_zip "${devfile_repo}" "${devfile_url##*/}" "$(pwd)/resources/v2/$name.zip"
  fi
done
