#!/bin/bash
#
# Copyright (c) 2018-2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

METAS_DIR=$(mktemp -d)

function cleanup() {
    rm -rf  "${METAS_DIR}";
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
    rm -rf "${METAS_DIR:?}"/*
}

function assertFileContentEquals() {
    file=$1
    expected_metayaml=$2

    if [[ $(cat "${file}") == "${expected_metayaml}" ]]; then
        echo -e "${GREEN}${EMOJI_PASS}${RESETSTYLE} Test passed!"
    else
        echo -e "${RED}${EMOJI_FAIL}${RESETSTYLE} Test failed!"
        echo "Result:"
        cat "${file}"
        echo "Expected:"
        echo "${expected_metayaml}"
        exit 1
    fi
}
echo -e "${BOLD}\n${EMOJI_HEADER}${EMOJI_HEADER}${EMOJI_HEADER} Running tests for entrypoint.sh: ${BASH_SOURCE[0]}${RESETSTYLE}"

#################################################################
initTest "Should replace image references in external_images.txt with RELATED_IMAGE env vars"

externalImagesTxt=$(cat <<-END
registry.redhat.io/devspaces/udi-rhel8:2.16
END
)
expected_externalImagesTxt=$(cat <<-END
registry.redhat.io/devspaces/udi-rhel8@sha256:becfa80ae0e0e86f815e8981c071a68952b6a488298d7525751585538a14d88e
END
)
echo "$externalImagesTxt" > "${METAS_DIR}/external_images.txt"

# NOTE: GIXDCNQK | base 32 -d = 2.16; GIXDCMIK | base 32 -d = 2.11 
export RELATED_IMAGE_devspaces_udi_plugin_registry_image_GIXDCNQK='registry.redhat.io/devspaces/udi-rhel8@sha256:becfa80ae0e0e86f815e8981c071a68952b6a488298d7525751585538a14d88e'

# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"
extract_and_use_related_images_env_variables_with_image_digest_info
assertFileContentEquals "${METAS_DIR}/external_images.txt" "${expected_externalImagesTxt}"

#################################################################
initTest "Should replace image references in che-code devfile.yaml with RELATED_IMAGE env vars "

devfileyaml=$(cat <<-END
schemaVersion: 2.1.0
metadata:
  name: che-code
commands:
  - id: init-container-command
    apply:
      component: che-code-injector
events:
  preStart:
    - init-container-command
components:
  - name: che-code-runtime-description
    container:
      image: registry.redhat.io/devspaces/udi-rhel8:3.5
      command:
        - /checode/entrypoint-volume.sh
      volumeMounts:
        - name: checode
          path: /checode
      memoryLimit: 1024Mi
      memoryRequest: 256Mi
      cpuLimit: 500m
      cpuRequest: 30m
      endpoints:
        - name: che-code
          attributes:
            type: main
            cookiesAuthEnabled: true
            discoverable: false
            urlRewriteSupported: true
          targetPort: 3100
          exposure: public
          secure: false
          protocol: https
        - name: code-redirect-1
          attributes:
            discoverable: false
            urlRewriteSupported: false
          targetPort: 13131
          exposure: public
          protocol: http
        - name: code-redirect-2
          attributes:
            discoverable: false
            urlRewriteSupported: false
          targetPort: 13132
          exposure: public
          protocol: http
        - name: code-redirect-3
          attributes:
            discoverable: false
            urlRewriteSupported: false
          targetPort: 13133
          exposure: public
          protocol: http
    attributes:
      app.kubernetes.io/component: che-code-runtime
      app.kubernetes.io/part-of: che-code.eclipse.org
      controller.devfile.io/container-contribution: true
  - name: checode
    volume: {}
  - name: che-code-injector
    container:
      image: registry.redhat.io/devspaces/code-rhel8:3.5
      command:
        - /entrypoint-init-container.sh
      volumeMounts:
        - name: checode
          path: /checode
      memoryLimit: 256Mi
      memoryRequest: 32Mi
      cpuLimit: 500m
      cpuRequest: 30m
END
)
expected_devfileyaml=$(cat <<-END
schemaVersion: 2.1.0
metadata:
  name: che-code
commands:
  - id: init-container-command
    apply:
      component: che-code-injector
events:
  preStart:
    - init-container-command
components:
  - name: che-code-runtime-description
    container:
      image: registry.redhat.io/devspaces/udi-rhel8@sha256:99ff1b5c541855e4cf368816c4bcdcdc86d32304023f72c4443213a4032ef05b
      command:
        - /checode/entrypoint-volume.sh
      volumeMounts:
        - name: checode
          path: /checode
      memoryLimit: 1024Mi
      memoryRequest: 256Mi
      cpuLimit: 500m
      cpuRequest: 30m
      endpoints:
        - name: che-code
          attributes:
            type: main
            cookiesAuthEnabled: true
            discoverable: false
            urlRewriteSupported: true
          targetPort: 3100
          exposure: public
          secure: false
          protocol: https
        - name: code-redirect-1
          attributes:
            discoverable: false
            urlRewriteSupported: false
          targetPort: 13131
          exposure: public
          protocol: http
        - name: code-redirect-2
          attributes:
            discoverable: false
            urlRewriteSupported: false
          targetPort: 13132
          exposure: public
          protocol: http
        - name: code-redirect-3
          attributes:
            discoverable: false
            urlRewriteSupported: false
          targetPort: 13133
          exposure: public
          protocol: http
    attributes:
      app.kubernetes.io/component: che-code-runtime
      app.kubernetes.io/part-of: che-code.eclipse.org
      controller.devfile.io/container-contribution: true
  - name: checode
    volume: {}
  - name: che-code-injector
    container:
      image: registry.redhat.io/devspaces/code-rhel8@sha256:debc18de31a6b3b575e42cc485f6c2241ee4d3d6988fad4e4e9837edba24f89f
      command:
        - /entrypoint-init-container.sh
      volumeMounts:
        - name: checode
          path: /checode
      memoryLimit: 256Mi
      memoryRequest: 32Mi
      cpuLimit: 500m
      cpuRequest: 30m
END
)
echo "$devfileyaml" > "${METAS_DIR}/devfile.yaml"
export RELATED_IMAGE_devspaces_code_plugin_registry_image_GMXDKCQ_='registry.redhat.io/devspaces/code-rhel8@sha256:debc18de31a6b3b575e42cc485f6c2241ee4d3d6988fad4e4e9837edba24f89f'
export RELATED_IMAGE_devspaces_udi_plugin_registry_image_GMXDKCQ_='registry.redhat.io/devspaces/udi-rhel8@sha256:99ff1b5c541855e4cf368816c4bcdcdc86d32304023f72c4443213a4032ef05b'

# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

extract_and_use_related_images_env_variables_with_image_digest_info

assertFileContentEquals "${METAS_DIR}/devfile.yaml" "${expected_devfileyaml}"
