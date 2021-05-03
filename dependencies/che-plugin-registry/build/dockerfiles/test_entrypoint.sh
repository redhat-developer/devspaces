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
          CHE_SIDECAR_CONTAINERS_REGISTRY_TAG

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
initTest "Should update image registry URL with CHE_SIDECAR_CONTAINERS_REGISTRY_URL. Multiple occurences."

metayaml=$(cat <<-END
spec:
 containers:
    - image: 'quay.io/eclipse/che-theia@sha256:69b7d27a9e9a4b46c2734d995456385bb0d7ab1022638d95ddaa5a5919ef43c1'
      env:
        - name: THEIA_PLUGINS
          value: 'local-dir:///plugins'
        - name: HOSTED_PLUGIN_HOSTNAME
          value: 0.0.0.0
        - name: HOSTED_PLUGIN_PORT
          value: '3130'
        - name: THEIA_HOST
          value: 127.0.0.1
      mountSources: true
      memoryLimit: 512M
      volumes:
        - name: plugins
          mountPath: /plugins
        - name: theia-local
          mountPath: /home/theia/.theia
      name: theia-ide
      ports:
        - exposedPort: 3100
        - exposedPort: 3130
        - exposedPort: 13131
        - exposedPort: 13132
        - exposedPort: 13133
    - image: 'quay.io/eclipse/che-machine-exec@sha256:98fdc3f341ed683dc0f07176729c887f2b965bade9c27d16dc0e05f9034e624c'
      command:
        - /go/bin/che-machine-exec
        - '--url'
        - '127.0.0.1:3333'
END
)
expected_metayaml=$(cat <<-END
spec:
 containers:
    - image: 'https://fakeregistry.io:5000/eclipse/che-theia@sha256:69b7d27a9e9a4b46c2734d995456385bb0d7ab1022638d95ddaa5a5919ef43c1'
      env:
        - name: THEIA_PLUGINS
          value: 'local-dir:///plugins'
        - name: HOSTED_PLUGIN_HOSTNAME
          value: 0.0.0.0
        - name: HOSTED_PLUGIN_PORT
          value: '3130'
        - name: THEIA_HOST
          value: 127.0.0.1
      mountSources: true
      memoryLimit: 512M
      volumes:
        - name: plugins
          mountPath: /plugins
        - name: theia-local
          mountPath: /home/theia/.theia
      name: theia-ide
      ports:
        - exposedPort: 3100
        - exposedPort: 3130
        - exposedPort: 13131
        - exposedPort: 13132
        - exposedPort: 13133
    - image: 'https://fakeregistry.io:5000/eclipse/che-machine-exec@sha256:98fdc3f341ed683dc0f07176729c887f2b965bade9c27d16dc0e05f9034e624c'
      command:
        - /go/bin/che-machine-exec
        - '--url'
        - '127.0.0.1:3333'
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
