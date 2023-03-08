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
    unset CHE_SIDECAR_CONTAINERS_REGISTRY_URL \
          CHE_SIDECAR_CONTAINERS_REGISTRY_ORGANIZATION \
          CHE_SIDECAR_CONTAINERS_REGISTRY_TAG \
          RELATED_IMAGE_devspaces_machineexec_plugin_registry_image_GIXDCMIK

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
initTest "Should update image registry URL. Simple quote."

metayaml=$(cat <<-END
spec:
  containers:
    - image: 'quay.io/eclipse/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d'
      name: asciidoctor-vscode
END
)
expected_metayaml=$(cat <<-END
spec:
  containers:
    - image: 'https://fakeregistry.io:5000/eclipse/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d'
      name: asciidoctor-vscode
END
)
echo "$metayaml" > "${METAS_DIR}/meta.yaml"
export CHE_SIDECAR_CONTAINERS_REGISTRY_URL='https://fakeregistry.io:5000'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

update_container_image_references

assertFileContentEquals "${METAS_DIR}/meta.yaml" "${expected_metayaml}"


#################################################################
initTest "Should update image registry URL with CHE_SIDECAR_CONTAINERS_REGISTRY_URL. Double quote."

metayaml=$(cat <<-END
spec:
  containers:
    - image: "quay.io/eclipse/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d"
      name: asciidoctor-vscode
END
)
expected_metayaml=$(cat <<-END
spec:
  containers:
    - image: "https://fakeregistry.io:5000/eclipse/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d"
      name: asciidoctor-vscode
END
)
echo "$metayaml" > "${METAS_DIR}/meta.yaml"
export CHE_SIDECAR_CONTAINERS_REGISTRY_URL='https://fakeregistry.io:5000'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

update_container_image_references

assertFileContentEquals "${METAS_DIR}/meta.yaml" "${expected_metayaml}"


#################################################################
initTest "Should update image registry URL with CHE_SIDECAR_CONTAINERS_REGISTRY_URL. Multiline."

metayaml=$(cat <<-END
spec:
  containers:
    - image: >-
        quay.io/eclipse/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d
      name: asciidoctor-vscode
END
)
expected_metayaml=$(cat <<-END
spec:
  containers:
    - image: >-
        https://fakeregistry.io:5000/eclipse/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d
      name: asciidoctor-vscode
END
)
echo "$metayaml" > "${METAS_DIR}/meta.yaml"
export CHE_SIDECAR_CONTAINERS_REGISTRY_URL='https://fakeregistry.io:5000'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

update_container_image_references

assertFileContentEquals "${METAS_DIR}/meta.yaml" "${expected_metayaml}"


#################################################################
initTest "Should update image organization with CHE_SIDECAR_CONTAINERS_REGISTRY_ORGANIZATION."
metayaml=$(cat <<-END
spec:
  containers:
    - image: 'quay.io/eclipse/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d'
      name: asciidoctor-vscode
END
)
expected_metayaml=$(cat <<-END
spec:
  containers:
    - image: 'quay.io/fakeorg/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d'
      name: asciidoctor-vscode
END
)
echo "$metayaml" > "${METAS_DIR}/meta.yaml"
export CHE_SIDECAR_CONTAINERS_REGISTRY_ORGANIZATION='fakeorg'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

update_container_image_references

assertFileContentEquals "${METAS_DIR}/meta.yaml" "${expected_metayaml}"


#################################################################
initTest "Should update image organization with CHE_SIDECAR_CONTAINERS_REGISTRY_ORGANIZATION. Multiline."

metayaml=$(cat <<-END
spec:
  containers:
    - image: >-
        quay.io/eclipse/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d
      name: asciidoctor-vscode
END
)
expected_metayaml=$(cat <<-END
spec:
  containers:
    - image: >-
        quay.io/fakeorg/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d
      name: asciidoctor-vscode
END
)
echo "$metayaml" > "${METAS_DIR}/meta.yaml"
export CHE_SIDECAR_CONTAINERS_REGISTRY_ORGANIZATION='fakeorg'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

update_container_image_references

assertFileContentEquals "${METAS_DIR}/meta.yaml" "${expected_metayaml}"


#################################################################
initTest "Should update image tag with CHE_SIDECAR_CONTAINERS_REGISTRY_TAG."

metayaml=$(cat <<-END
spec:
  containers:
    - image: 'quay.io/eclipse/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d'
      name: asciidoctor-vscode
END
)
expected_metayaml=$(cat <<-END
spec:
  containers:
    - image: 'quay.io/eclipse/che-plugin-sidecar:faketag'
      name: asciidoctor-vscode
END
)
echo "$metayaml" > "${METAS_DIR}/meta.yaml"
export CHE_SIDECAR_CONTAINERS_REGISTRY_TAG='faketag'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

update_container_image_references

assertFileContentEquals "${METAS_DIR}/meta.yaml" "${expected_metayaml}"


#################################################################
initTest "Should update image tag with CHE_SIDECAR_CONTAINERS_REGISTRY_TAG. Multiline."

metayaml=$(cat <<-END
spec:
  containers:
    - image: >-
        quay.io/eclipse/che-plugin-sidecar@sha256:d565b98f110efe4246fe1f25ee62d74d70f4f999e4679e8f7085f18b1711f76d
      name: asciidoctor-vscode
END
)
expected_metayaml=$(cat <<-END
spec:
  containers:
    - image: >-
        quay.io/eclipse/che-plugin-sidecar:faketag
      name: asciidoctor-vscode
END
)
echo "$metayaml" > "${METAS_DIR}/meta.yaml"
export CHE_SIDECAR_CONTAINERS_REGISTRY_TAG='faketag'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

update_container_image_references

assertFileContentEquals "${METAS_DIR}/meta.yaml" "${expected_metayaml}"


#################################################################
initTest "Should do nothing."

metayaml=$(cat <<-END
spec:
  containers:
    - image: 'name'
      name: asciidoctor-vscode
END
)
expected_metayaml=$(cat <<-END
spec:
  containers:
    - image: 'name'
      name: asciidoctor-vscode
END
)
echo "$metayaml" > "${METAS_DIR}/meta.yaml"
export CHE_SIDECAR_CONTAINERS_REGISTRY_URL='https://fakeregistry.io:5000'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

update_container_image_references

assertFileContentEquals "${METAS_DIR}/meta.yaml" "${expected_metayaml}"

#################################################################
initTest "Should replace image references in che-machine-exec-plugin devfile.yaml with RELATED_IMAGE env vars "

devfileyaml=$(cat <<-END
schemaVersion: 2.1.0
metadata:
  name: Che machine-exec Service
components:
  - name: che-machine-exec
    container:
      image: 'registry.redhat.io/devspaces/machineexec-rhel8:2.11'
      command:
        - /go/bin/che-machine-exec
        - '--url'
        - '0.0.0.0:4444'
      memoryLimit: 128Mi
      memoryRequest: 32Mi
      cpuLimit: 500m
      cpuRequest: 30m
      endpoints:
        - name: che-machine-exec
          attributes:
            type: terminal
            discoverable: false
            cookiesAuthEnabled: true
          targetPort: 4444
          exposure: public
          secure: false
          protocol: wss
END
)
expected_devfileyaml=$(cat <<-END
schemaVersion: 2.1.0
metadata:
  name: Che machine-exec Service
components:
  - name: che-machine-exec
    container:
      image: 'registry.redhat.io/devspaces/machineexec-rhel8@sha256:bfdd8cf61a6fad757f1e8334aa84dbf44baddf897ff8def7496bf6dbc066679d'
      command:
        - /go/bin/che-machine-exec
        - '--url'
        - '0.0.0.0:4444'
      memoryLimit: 128Mi
      memoryRequest: 32Mi
      cpuLimit: 500m
      cpuRequest: 30m
      endpoints:
        - name: che-machine-exec
          attributes:
            type: terminal
            discoverable: false
            cookiesAuthEnabled: true
          targetPort: 4444
          exposure: public
          secure: false
          protocol: wss
END
)
echo "$devfileyaml" > "${METAS_DIR}/devfile.yaml"
export RELATED_IMAGE_devspaces_machineexec_plugin_registry_image_GIXDCMIK='registry.redhat.io/devspaces/machineexec-rhel8@sha256:bfdd8cf61a6fad757f1e8334aa84dbf44baddf897ff8def7496bf6dbc066679d'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

extract_and_use_related_images_env_variables_with_image_digest_info

assertFileContentEquals "${METAS_DIR}/devfile.yaml" "${expected_devfileyaml}"


#################################################################
initTest "Should replace image references in external_images.txt with RELATED_IMAGE env vars"

externalImagesTxt=$(cat <<-END
registry.redhat.io/devspaces/machineexec-rhel8:2.11
registry.redhat.io/devspaces/udi-rhel8:2.16
END
)
expected_externalImagesTxt=$(cat <<-END
registry.redhat.io/devspaces/machineexec-rhel8@sha256:bfdd8cf61a6fad757f1e8334aa84dbf44baddf897ff8def7496bf6dbc066679d
registry.redhat.io/devspaces/udi-rhel8@sha256:becfa80ae0e0e86f815e8981c071a68952b6a488298d7525751585538a14d88e
END
)
echo "$externalImagesTxt" > "${METAS_DIR}/external_images.txt"

# NOTE: GIXDCNQK | base 32 -d = 2.16; GIXDCMIK | base 32 -d = 2.11 
export RELATED_IMAGE_devspaces_machineexec_plugin_registry_image_GIXDCMIK='registry.redhat.io/devspaces/machineexec-rhel8@sha256:bfdd8cf61a6fad757f1e8334aa84dbf44baddf897ff8def7496bf6dbc066679d'
export RELATED_IMAGE_devspaces_udi_plugin_registry_image_GIXDCNQK='registry.redhat.io/devspaces/udi-rhel8@sha256:becfa80ae0e0e86f815e8981c071a68952b6a488298d7525751585538a14d88e'

# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"
extract_and_use_related_images_env_variables_with_image_digest_info
assertFileContentEquals "${METAS_DIR}/external_images.txt" "${expected_externalImagesTxt}"
