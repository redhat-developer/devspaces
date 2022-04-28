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
registry.redhat.io/rhscl/mongodb-36-rhel7:1-50
registry.redhat.io/devspaces/udi-rhel8:2.16
END
)
expected_externalImagesTxt=$(cat <<-END
registry.redhat.io/rhscl/mongodb-36-rhel7@sha256:9f799d356d7d2e442bde9d401b720600fd9059a3d8eefea6f3b2ffa721c0dc73
registry.redhat.io/devspaces/udi-rhel8@sha256:becfa80ae0e0e86f815e8981c071a68952b6a488298d7525751585538a14d88e
END
)

echo "$externalImagesTxt" > "${DEVFILES_DIR}/external_images.txt"

# NOTE: GIXDCNQK | base 32 -d = 2.16; GIXDCMIK | base 32 -d = 2.11 
export RELATED_IMAGE_rhscl_mongodb_36_rhel7_devfile_registry_image_GEWTKMAK='registry.redhat.io/rhscl/mongodb-36-rhel7@sha256:9f799d356d7d2e442bde9d401b720600fd9059a3d8eefea6f3b2ffa721c0dc73'
export RELATED_IMAGE_devspaces_udi_devfile_registry_image_GIXDCNQK='registry.redhat.io/devspaces/udi-rhel8@sha256:becfa80ae0e0e86f815e8981c071a68952b6a488298d7525751585538a14d88e'

# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"
extract_and_use_related_images_env_variables_with_image_digest_info
assertFileContentEquals "${DEVFILES_DIR}/external_images.txt" "${expected_externalImagesTxt}"

#################################################################
initTest "Should replace image references in devworkspace-che-theia-latest.yaml with RELATED_IMAGE env vars"

externalImagesTxt=$(cat <<-END
registry.redhat.io/devspaces/theia-rhel8:2.15
END
)
expected_externalImagesTxt=$(cat <<-END
registry.redhat.io/devspaces/theia-rhel8@sha256:833f332f1e7f9a669b658bd6d1bf7f236c52ecf141a7006637fbda9f86fc5369
END
)

devworkspace=$(cat <<-END
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspaceTemplate
metadata:
  name: theia-ide-python-hello-world
spec:
  commands:
    - id: init-container-command
      apply:
        component: remote-runtime-injector
  events:
    preStart:
      - init-container-command
  components:
    - name: theia-ide
      container:
        image: registry.redhat.io/devspaces/theia-rhel8:2.15
END
)

expected_devworkspace=$(cat <<-END
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspaceTemplate
metadata:
  name: theia-ide-python-hello-world
spec:
  commands:
    - id: init-container-command
      apply:
        component: remote-runtime-injector
  events:
    preStart:
      - init-container-command
  components:
    - name: theia-ide
      container:
        image: registry.redhat.io/devspaces/theia-rhel8@sha256:833f332f1e7f9a669b658bd6d1bf7f236c52ecf141a7006637fbda9f86fc5369
END
)

echo "$externalImagesTxt" > "${DEVFILES_DIR}/external_images.txt"
echo "$devworkspace" > "${DEVFILES_DIR}/devworkspace-che-theia-latest.yaml"

# NOTE: GIXDCNQK | base 32 -d = 2.16; GIXDCMIK | base 32 -d = 2.11 
export RELATED_IMAGE_devspaces_theia_devfile_registry_image_GIXDCNIK='registry.redhat.io/devspaces/theia-rhel8@sha256:833f332f1e7f9a669b658bd6d1bf7f236c52ecf141a7006637fbda9f86fc5369'

# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"
extract_and_use_related_images_env_variables_with_image_digest_info
assertFileContentEquals "${DEVFILES_DIR}/devworkspace-che-theia-latest.yaml" "${expected_devworkspace}"

#######################################################################################
initTest "Should replace INTERNAL_URL in devworkspace-che-theia-latest.yaml"

devworkspace=$(cat <<-END
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: bash
spec:
  started: true
  template:
    components:
      - name: tools
        container:
          image: quay.io/devfile/universal-developer-image:ubi8-0e189d9
          memoryLimit: 3Gi
      - name: theia-ide-bash
        plugin:
          kubernetes:
            name: theia-ide-bash
    projects:
      - name: bash
        zip:
          location: '{{ INTERNAL_URL }}/resources/v2/bash.zip'
END
)

expected_devworkspace=$(cat <<-END
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: bash
spec:
  started: true
  template:
    components:
      - name: tools
        container:
          image: quay.io/devfile/universal-developer-image:ubi8-0e189d9
          memoryLimit: 3Gi
      - name: theia-ide-bash
        plugin:
          kubernetes:
            name: theia-ide-bash
    projects:
      - name: bash
        zip:
          location: 'http://devfile-registry.devspaces.svc:8080/resources/v2/bash.zip'
END
)

echo "$devworkspace" > "${DEVFILES_DIR}/devworkspace-che-theia-latest.yaml"
touch "${DEVFILES_DIR}/index.json"

# NOTE: GIXDCNQK | base 32 -d = 2.16; GIXDCMIK | base 32 -d = 2.11 
export CHE_DEVFILE_REGISTRY_INTERNAL_URL='http://devfile-registry.devspaces.svc:8080'

# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"
set_internal_url
assertFileContentEquals "${DEVFILES_DIR}/devworkspace-che-theia-latest.yaml" "${expected_devworkspace}"
