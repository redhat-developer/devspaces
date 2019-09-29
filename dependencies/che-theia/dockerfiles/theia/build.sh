#!/bin/bash
#
# Copyright (c) 2018-2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

# Define upstream version of theia to use
THEIA_VERSION=master
THEIA_GITHUB_REPO=eclipse-theia/theia
GIT_BRANCH_NAME=v0.11.0 # use tag v0.11.0 or branch master
if [[ -d theia-source-code ]]; then rm -fr theia-source-code; fi
echo "Check out https://github.com/${THEIA_GITHUB_REPO} from branch ${GIT_BRANCH_NAME} to ./theia-source-code ..."
git clone -q --branch ${GIT_BRANCH_NAME} --single-branch --depth 1 https://github.com/${THEIA_GITHUB_REPO} theia-source-code

CHE_THEIA_GIT_BRANCH_NAME=7.2.0
CHE_THEIA_GITHUB_REPO=eclipse/che-theia
if [[ -d theia-source-code/che-theia ]]; then rm -fr theia-source-code/che-theia; fi
echo "Check out https://github.com/${CHE_THEIA_GITHUB_REPO} from branch ${CHE_THEIA_GIT_BRANCH_NAME} to ./theia-source-code/che-theia ..."
git clone -q --branch ${CHE_THEIA_GIT_BRANCH_NAME} --single-branch --depth 1 https://github.com/${CHE_THEIA_GITHUB_REPO} theia-source-code/che-theia

base_dir=$(cd "$(dirname "$0")"; pwd)
. "${base_dir}"/../build.include

# check_github_limits

# DIR=$(cd "$(dirname "$0")"; pwd)
# LOCAL_ASSEMBLY_DIR="${DIR}"/che-theia

# if [ -d "${LOCAL_ASSEMBLY_DIR}" ]; then
#   rm -r "${LOCAL_ASSEMBLY_DIR}"
# fi

# # In mac os 'cp' cannot create destination dir, so create it first
# mkdir -p ${LOCAL_ASSEMBLY_DIR}

# echo "Compresing 'che-theia' --> ${LOCAL_ASSEMBLY_DIR}/che-theia.tar.gz"
# pushd "${DIR}"/../.. >/dev/null 
#   git ls-files -z -c -o --exclude-standard | xargs -0 tar rf ${LOCAL_ASSEMBLY_DIR}/che-theia.tar
# popd >/dev/null

init --name:theia "$@"

if [ "${CDN_PREFIX:-}" != "" ]; then
  BUILD_ARGS+="--build-arg CDN_PREFIX=${CDN_PREFIX} "
fi

if [ "${MONACO_CDN_PREFIX:-}" != "" ]; then
  BUILD_ARGS+="--build-arg MONACO_CDN_PREFIX=${MONACO_CDN_PREFIX} "
fi

echo "Build image theia using FROM ${ORGANIZATION}/${PREFIX}-theia-dev:${TAG} ..."
build Dockerfile
if [[ $SKIP_TESTS == "false" ]] && [[ -x "${base_dir}"/e2e/build.sh ]]; then
  bash "${base_dir}"/e2e/build.sh "$PREFIX-$NAME" "$@"
else
  echo "E2E tests skipped."
fi

if [[ -x "${base_dir}"/extract-for-cdn.sh ]]; then
  echo "Extracting artifacts for the CDN"
  mkdir -p "${base_dir}/theia_artifacts"
  "${base_dir}"/extract-for-cdn.sh "$IMAGE_NAME" "${base_dir}/theia_artifacts"
  LABEL_CONTENT=$(cat "${base_dir}"/theia_artifacts/cdn.json || true 2>/dev/null)
  if [[ -n "${LABEL_CONTENT}" ]] && [[ -x "${base_dir}"/push-cdn-files-to-akamai.sh ]]; then
    BUILD_ARGS+="--label che-plugin.cdn.artifacts=$(echo ${LABEL_CONTENT} | sed 's/ //g') "
    echo "Rebuilding with CDN label..."
    build
    "${base_dir}"/push-cdn-files-to-akamai.sh
  fi
fi