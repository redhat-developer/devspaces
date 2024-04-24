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

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# shellcheck disable=SC1091
source "${script_dir}/clone_and_zip.sh"
if [[ -f VERSION ]]; then 
  VERSION=$(cat VERSION)
elif [[ -f ../VERSION ]]; then 
  VERSION=$(cat ../VERSION)
elif [[ -f ../../VERSION ]]; then 
  VERSION=$(cat ../../VERSION)
else
  VERSION="$1"
fi
if [[ -z $VERSION ]]; then 
  echo "Error: could not find VERSION, ../VERSION, or ../../VERSION file; set version on commandline, eg., $0 3.y"
  exit 1
fi

arch="$(uname -m)"

# Install che-devworkspace-generator
che_devworkspace_generator="che-devworkspace-generator"
npm install @eclipse-che/"${che_devworkspace_generator}"@"$(jq -r --arg v $che_devworkspace_generator '.[$v]' versions.json)"

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
    project="${name}={{_INTERNAL_URL_}}/resources/v2/${name}.zip"

    # Generate devworkspace-che-code-latest.yaml
    npm_config_yes=true npx @eclipse-che/${che_devworkspace_generator} \
    --devfile-url:"${devfile_url}" \
    --editor-entry:che-incubator/che-code/latest \
    --plugin-registry-url:https://redhat-developer.github.io/devspaces/che-plugin-registry/"${VERSION}"/"${arch}"/v3 \
    --output-file:"${dir}"devworkspace-che-code-latest.yaml \
    --project."${project}"

    # Generate devworkspace-che-idea-latest.yaml
    npm_config_yes=true npx @eclipse-che/${che_devworkspace_generator} \
    --devfile-url:"${devfile_url}" \
    --editor-entry:che-incubator/che-idea/latest \
    --plugin-registry-url:https://redhat-developer.github.io/devspaces/che-plugin-registry/"${VERSION}"/"${arch}"/v3 \
    --output-file:"${dir}"/devworkspace-che-idea-latest.yaml \
    --project."${project}"

    clone_and_zip "${devfile_repo}" "${devfile_url##*/}" "$(pwd)/resources/v2/$name.zip"
  fi
done
