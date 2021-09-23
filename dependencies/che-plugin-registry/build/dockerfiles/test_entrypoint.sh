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
          RELATED_IMAGE_codeready_workspaces_theia_endpoint_plugin_registry_image_GIXDCMIK \
          RELATED_IMAGE_codeready_workspaces_machineexec_plugin_registry_image_GIXDCMIK \
          RELATED_IMAGE_codeready_workspaces_theia_plugin_registry_image_GIXDCMIK

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

#################################################################
initTest "Should replace 2.11 image references in theia-ide devfile.yaml with RELATED_IMAGE env vars "

devfileyaml=$(cat <<-END
schemaVersion: 2.1.0
metadata:
  name: theia-ide
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
      image: 'registry.redhat.io/codeready-workspaces/theia-rhel8:2.11'
      env:
        - name: THEIA_PLUGINS
          value: 'local-dir:///plugins'
        - name: HOSTED_PLUGIN_HOSTNAME
          value: 0.0.0.0
        - name: HOSTED_PLUGIN_PORT
          value: '3130'
        - name: THEIA_HOST
          value: 0.0.0.0
      volumeMounts:
        - name: plugins
          path: /plugins
        - name: theia-local
          path: /home/theia/.theia
      mountSources: true
      memoryLimit: 512M
      cpuLimit: 1500m
      cpuRequest: 100m
      endpoints:
        - name: theia
          attributes:
            type: main
            cookiesAuthEnabled: true
            discoverable: false
          targetPort: 3100
          exposure: public
          secure: false
          protocol: https
        - name: webviews
          attributes:
            type: webview
            cookiesAuthEnabled: true
            discoverable: false
            unique: true
          targetPort: 3100
          exposure: public
          secure: false
          protocol: https
        - name: mini-browser
          attributes:
            type: mini-browser
            cookiesAuthEnabled: true
            discoverable: false
            unique: true
          targetPort: 3100
          exposure: public
          secure: false
          protocol: https
        - name: theia-dev
          attributes:
            type: ide-dev
            discoverable: false
          targetPort: 3130
          exposure: public
          protocol: http
        - name: theia-redirect-1
          attributes:
            discoverable: false
          targetPort: 13131
          exposure: public
          protocol: http
        - name: theia-redirect-2
          attributes:
            discoverable: false
          targetPort: 13132
          exposure: public
          protocol: http
        - name: theia-redirect-3
          attributes:
            discoverable: false
          targetPort: 13133
          exposure: public
          protocol: http
        - name: terminal
          attributes:
            type: collocated-terminal
            discoverable: false
            cookiesAuthEnabled: true
          targetPort: 3333
          exposure: public
          secure: false
          protocol: wss
    attributes: {}
  - name: plugins
    volume: {}
  - name: theia-local
    volume: {}
  - name: che-machine-exec
    container:
      image: 'registry.redhat.io/codeready-workspaces/machineexec-rhel8:2.11'
      command:
        - /go/bin/che-machine-exec
        - '--url'
        - '0.0.0.0:3333'
      memoryLimit: 128Mi
      memoryRequest: 32Mi
      cpuLimit: 500m
      cpuRequest: 30m
    attributes: {}
  - name: remote-runtime-injector
    container:
      image: 'registry.redhat.io/codeready-workspaces/theia-endpoint-rhel8:2.11'
      env:
        - name: PLUGIN_REMOTE_ENDPOINT_EXECUTABLE
          value: /remote-endpoint/plugin-remote-endpoint
        - name: REMOTE_ENDPOINT_VOLUME_NAME
          value: remote-endpoint
      volumeMounts:
        - name: remote-endpoint
          path: /remote-endpoint
      memoryLimit: 128Mi
      memoryRequest: 32Mi
      cpuLimit: 500m
      cpuRequest: 30m
  - name: remote-endpoint
    volume:
      ephemeral: true
END
)
expected_devfileyaml=$(cat <<-END
schemaVersion: 2.1.0
metadata:
  name: theia-ide
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
      image: 'registry.redhat.io/codeready-workspaces/theia-rhel8@sha256:be279f90a9aeeb885fcedca4749396ce16825eb66947900b549cfdf16f97dfeb'
      env:
        - name: THEIA_PLUGINS
          value: 'local-dir:///plugins'
        - name: HOSTED_PLUGIN_HOSTNAME
          value: 0.0.0.0
        - name: HOSTED_PLUGIN_PORT
          value: '3130'
        - name: THEIA_HOST
          value: 0.0.0.0
      volumeMounts:
        - name: plugins
          path: /plugins
        - name: theia-local
          path: /home/theia/.theia
      mountSources: true
      memoryLimit: 512M
      cpuLimit: 1500m
      cpuRequest: 100m
      endpoints:
        - name: theia
          attributes:
            type: main
            cookiesAuthEnabled: true
            discoverable: false
          targetPort: 3100
          exposure: public
          secure: false
          protocol: https
        - name: webviews
          attributes:
            type: webview
            cookiesAuthEnabled: true
            discoverable: false
            unique: true
          targetPort: 3100
          exposure: public
          secure: false
          protocol: https
        - name: mini-browser
          attributes:
            type: mini-browser
            cookiesAuthEnabled: true
            discoverable: false
            unique: true
          targetPort: 3100
          exposure: public
          secure: false
          protocol: https
        - name: theia-dev
          attributes:
            type: ide-dev
            discoverable: false
          targetPort: 3130
          exposure: public
          protocol: http
        - name: theia-redirect-1
          attributes:
            discoverable: false
          targetPort: 13131
          exposure: public
          protocol: http
        - name: theia-redirect-2
          attributes:
            discoverable: false
          targetPort: 13132
          exposure: public
          protocol: http
        - name: theia-redirect-3
          attributes:
            discoverable: false
          targetPort: 13133
          exposure: public
          protocol: http
        - name: terminal
          attributes:
            type: collocated-terminal
            discoverable: false
            cookiesAuthEnabled: true
          targetPort: 3333
          exposure: public
          secure: false
          protocol: wss
    attributes: {}
  - name: plugins
    volume: {}
  - name: theia-local
    volume: {}
  - name: che-machine-exec
    container:
      image: 'registry.redhat.io/codeready-workspaces/machineexec-rhel8@sha256:bfdd8cf61a6fad757f1e8334aa84dbf44baddf897ff8def7496bf6dbc066679d'
      command:
        - /go/bin/che-machine-exec
        - '--url'
        - '0.0.0.0:3333'
      memoryLimit: 128Mi
      memoryRequest: 32Mi
      cpuLimit: 500m
      cpuRequest: 30m
    attributes: {}
  - name: remote-runtime-injector
    container:
      image: 'registry.redhat.io/codeready-workspaces/theia-endpoint-rhel8@sha256:cda289285594c87d1acfb77543aae109973cd1b84953bde061a27889423979c5'
      env:
        - name: PLUGIN_REMOTE_ENDPOINT_EXECUTABLE
          value: /remote-endpoint/plugin-remote-endpoint
        - name: REMOTE_ENDPOINT_VOLUME_NAME
          value: remote-endpoint
      volumeMounts:
        - name: remote-endpoint
          path: /remote-endpoint
      memoryLimit: 128Mi
      memoryRequest: 32Mi
      cpuLimit: 500m
      cpuRequest: 30m
  - name: remote-endpoint
    volume:
      ephemeral: true
END
)
echo "$devfileyaml" > "${METAS_DIR}/devfile.yaml"
export RELATED_IMAGE_codeready_workspaces_theia_endpoint_plugin_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/theia-endpoint-rhel8@sha256:cda289285594c87d1acfb77543aae109973cd1b84953bde061a27889423979c5'
export RELATED_IMAGE_codeready_workspaces_machineexec_plugin_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/machineexec-rhel8@sha256:bfdd8cf61a6fad757f1e8334aa84dbf44baddf897ff8def7496bf6dbc066679d'
export RELATED_IMAGE_codeready_workspaces_theia_plugin_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/theia-rhel8@sha256:be279f90a9aeeb885fcedca4749396ce16825eb66947900b549cfdf16f97dfeb'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

extract_and_use_related_images_env_variables_with_image_digest_info

assertFileContentEquals "${METAS_DIR}/devfile.yaml" "${expected_devfileyaml}"




#################################################################
initTest "Should replace 2.11 image references in che-machine-exec-plugin devfile.yaml with RELATED_IMAGE env vars "

devfileyaml=$(cat <<-END
schemaVersion: 2.1.0
metadata:
  name: Che machine-exec Service
components:
  - name: che-machine-exec
    container:
      image: 'registry.redhat.io/codeready-workspaces/machineexec-rhel8:2.11'
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
      image: 'registry.redhat.io/codeready-workspaces/machineexec-rhel8@sha256:bfdd8cf61a6fad757f1e8334aa84dbf44baddf897ff8def7496bf6dbc066679d'
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
export RELATED_IMAGE_codeready_workspaces_theia_endpoint_plugin_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/theia-endpoint-rhel8@sha256:cda289285594c87d1acfb77543aae109973cd1b84953bde061a27889423979c5'
export RELATED_IMAGE_codeready_workspaces_machineexec_plugin_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/machineexec-rhel8@sha256:bfdd8cf61a6fad757f1e8334aa84dbf44baddf897ff8def7496bf6dbc066679d'
export RELATED_IMAGE_codeready_workspaces_theia_plugin_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/theia-rhel8@sha256:be279f90a9aeeb885fcedca4749396ce16825eb66947900b549cfdf16f97dfeb'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

extract_and_use_related_images_env_variables_with_image_digest_info

assertFileContentEquals "${METAS_DIR}/devfile.yaml" "${expected_devfileyaml}"

#################################################################
initTest "Should replace image references in che-theia-plugin.yaml with RELATED_IMAGE env vars "

cheTheiaPluginYaml=$(cat <<-END
schemaVersion: 1.0.0
metadata:
  id: redhat/java11
  publisher: redhat
  name: java11
  version: latest
  displayName: Language Support for Java(TM) by Red Hat
  description: 'Java Linting, Intellisense, formatting, refactoring, Maven/Gradle support and more...'
  repository: 'https://github.com/redhat-developer/vscode-java'
  categories:
    - Programming Languages
    - Linters
    - Formatters
    - Snippets
  icon: /images/redhat-java-icon.png
sidecar:
  image: 'registry.redhat.io/codeready-workspaces/plugin-java11-rhel8:2.11'
  name: vscode-java
  memoryLimit: 1500Mi
  cpuLimit: 500m
  cpuRequest: 30m
extensions:
  - 'relative:extension/resources/download_jboss_org/jbosstools/static/jdt_ls/stable/java-0.75.0-60.vsix'
END
)
expected_cheTheiaPluginYaml=$(cat <<-END
schemaVersion: 1.0.0
metadata:
  id: redhat/java11
  publisher: redhat
  name: java11
  version: latest
  displayName: Language Support for Java(TM) by Red Hat
  description: 'Java Linting, Intellisense, formatting, refactoring, Maven/Gradle support and more...'
  repository: 'https://github.com/redhat-developer/vscode-java'
  categories:
    - Programming Languages
    - Linters
    - Formatters
    - Snippets
  icon: /images/redhat-java-icon.png
sidecar:
  image: 'registry.redhat.io/codeready-workspaces/plugin-java11-rhel8@sha256:d0337762e71fd4badabcb38a582b2f35e7e7fc1c9c0f2e841e339d45b7bd34ed'
  name: vscode-java
  memoryLimit: 1500Mi
  cpuLimit: 500m
  cpuRequest: 30m
extensions:
  - 'relative:extension/resources/download_jboss_org/jbosstools/static/jdt_ls/stable/java-0.75.0-60.vsix'
END
)
echo "$cheTheiaPluginYaml" > "${METAS_DIR}/che-theia-plugin.yaml"
export RELATED_IMAGE_codeready_workspaces_plugin_java11_plugin_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/plugin-java11-rhel8@sha256:d0337762e71fd4badabcb38a582b2f35e7e7fc1c9c0f2e841e339d45b7bd34ed'
# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"

extract_and_use_related_images_env_variables_with_image_digest_info

assertFileContentEquals "${METAS_DIR}/che-theia-plugin.yaml" "${expected_cheTheiaPluginYaml}"

#################################################################
initTest "Should replace image references in external_images.txt with RELATED_IMAGE env vars"

externalImagesTxt=$(cat <<-END
registry.redhat.io/codeready-workspaces/machineexec-rhel8:2.11
registry.redhat.io/codeready-workspaces/plugin-java11-rhel8:2.11
registry.redhat.io/codeready-workspaces/stacks-golang-rhel8:2.11
END
)
expected_externalImagesTxt=$(cat <<-END
registry.redhat.io/codeready-workspaces/machineexec-rhel8@sha256:bfdd8cf61a6fad757f1e8334aa84dbf44baddf897ff8def7496bf6dbc066679d
registry.redhat.io/codeready-workspaces/plugin-java11-rhel8@sha256:d0337762e71fd4badabcb38a582b2f35e7e7fc1c9c0f2e841e339d45b7bd34ed
registry.redhat.io/codeready-workspaces/stacks-golang-rhel8@sha256:30e71577cb80ffaf1f67a292b4c96ab74108a2361347fc593cbb505784629db2

END
)

echo "$externalImagesTxt" > "${METAS_DIR}/external_images.txt"

export RELATED_IMAGE_codeready_workspaces_machineexec_plugin_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/machineexec-rhel8@sha256:bfdd8cf61a6fad757f1e8334aa84dbf44baddf897ff8def7496bf6dbc066679d'
export RELATED_IMAGE_codeready_workspaces_plugin_java11_plugin_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/plugin-java11-rhel8@sha256:d0337762e71fd4badabcb38a582b2f35e7e7fc1c9c0f2e841e339d45b7bd34ed'
export RELATED_IMAGE_codeready_workspaces_stacks_golang_plugin_registry_image_GIXDCMIK='registry.redhat.io/codeready-workspaces/stacks-golang-rhel8@sha256:30e71577cb80ffaf1f67a292b4c96ab74108a2361347fc593cbb505784629db2'

# shellcheck disable=SC1090
source "${script_dir}/entrypoint.sh"
extract_and_use_related_images_env_variables_with_image_digest_info
assertFileContentEquals "${METAS_DIR}/external_images.txt" "${expected_externalImagesTxt}"
