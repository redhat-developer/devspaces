#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DEVFILES_DIR=$(mktemp -d)

function cleanup() {
    rm -rf  "${DEVFILES_DIR}";
}
trap cleanup EXIT

RED="\e[31m"
GREEN="\e[32m"
RESETSTYLE="\e[0m"
BOLD="\e[1m"
DEFAULT_EMOJI_HEADER="🏃" # could be overiden with EMOJI_HEADER="-"
EMOJI_HEADER=${EMOJI_HEADER:-$DEFAULT_EMOJI_HEADER}
DEFAULT_EMOJI_PASS="✔" # could be overriden with EMOJI_PASS="[PASS]"
EMOJI_PASS=${EMOJI_PASS:-$DEFAULT_EMOJI_PASS}
DEFAULT_EMOJI_FAIL="✘" # could be overriden with EMOJI_FAIL="[FAIL]"
EMOJI_FAIL=${EMOJI_FAIL:-$DEFAULT_EMOJI_FAIL}

function initTest() {
    echo -e "${BOLD}\n${EMOJI_HEADER} ${1}${RESETSTYLE}"
    rm -rf "${DEVFILES_DIR:?}"/*
    unset CHE_SIDECAR_CONTAINERS_REGISTRY_URL \
          CHE_SIDECAR_CONTAINERS_REGISTRY_ORGANIZATION \
          CHE_SIDECAR_CONTAINERS_REGISTRY_TAG
}

function assertFileContentEquals() {
    file=$1
    expected_devfileyaml=$2

    if [[ $(cat "${file}") == "${expected_devfileyaml}" ]]; then
        echo -e "${GREEN}${EMOJI_PASS}${RESETSTYLE} Test passed!"
    else
        echo -e "${RED}${EMOJI_FAIL}${RESETSTYLE} Test failed!"
        echo "Result:"
        cat "${file}"
        echo "Expected:"
        echo "${expected_devfileyaml}"
        exit 1
    fi
}
echo -e "${BOLD}\n${EMOJI_HEADER}${EMOJI_HEADER}${EMOJI_HEADER} Running tests for entrypoint.sh: ${BASH_SOURCE[0]}${RESETSTYLE}"

#################################################################
initTest "Should replace image references in external_images.txt with RELATED_IMAGE env vars"

externalImagesTxt=$(cat <<-END
registry.redhat.io/codeready-workspaces/stacks-dotnet-rhel8:2.11
registry.redhat.io/codeready-workspaces/plugin-java11-rhel8:2.11
registry.redhat.io/rhscl/mongodb-36-rhel7:1-50
END
)
expected_externalImagesTxt=$(cat <<-END
registry.redhat.io/codeready-workspaces/stacks-dotnet-rhel8@sha256:6ca14e5a94a98b15f39a353e533cf659b2b3937a86bd51af175dc3eadd8b80d5
registry.redhat.io/codeready-workspaces/plugin-java11-rhel8@sha256:d0337762e71fd4badabcb38a582b2f35e7e7fc1c9c0f2e841e339d45b7bd34ed
registry.redhat.io/rhscl/mongodb-36-rhel7@sha256:9f799d356d7d2e442bde9d401b720600fd9059a3d8eefea6f3b2ffa721c0dc73

END
)

echo "$externalImagesTxt" > "${DEVFILES_DIR}/external_images.txt"

export RELATED_IMAGE_codeready_workspaces_plugin_java11_devfile_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/plugin-java11-rhel8@sha256:d0337762e71fd4badabcb38a582b2f35e7e7fc1c9c0f2e841e339d45b7bd34ed'
export RELATED_IMAGE_codeready_workspaces_stacks_dotnet_devfile_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/stacks-dotnet-rhel8@sha256:6ca14e5a94a98b15f39a353e533cf659b2b3937a86bd51af175dc3eadd8b80d5'
export RELATED_IMAGE_rhscl_mongodb_36_rhel7_devfile_registry_image_GEWTKMAK='registry.redhat.io/rhscl/mongodb-36-rhel7@sha256:9f799d356d7d2e442bde9d401b720600fd9059a3d8eefea6f3b2ffa721c0dc73'

# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"
extract_and_use_related_images_env_variables_with_image_digest_info
assertFileContentEquals "${DEVFILES_DIR}/external_images.txt" "${expected_externalImagesTxt}"
