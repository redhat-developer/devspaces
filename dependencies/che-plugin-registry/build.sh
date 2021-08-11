#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

set -e

base_dir=$(cd "$(dirname "$0")"; pwd)

REGISTRY="quay.io"
ORGANIZATION="crw"
TAG="nightly"
DOCKERFILE="./build/dockerfiles/Dockerfile"
SKIP_OCI_IMAGE="false"
NODE_BUILD_OPTIONS="${NODE_BUILD_OPTIONS:-}"
BUILD_FLAGS_ARRAY=()

USAGE="
Usage: ./build.sh [OPTIONS]
Options:
    --help
        Print this message.
    --tag, -t [TAG]
        Docker image tag to be used for image; default: 'nightly'
    --registry, -r [REGISTRY]
        Docker registry to be used for image; default 'quay.io'
    --organization, -o [ORGANIZATION]
        Docker image organization to be used for image; default: 'eclipse'
    --offline
        Build offline version of registry, with all artifacts included
        cached in the registry; disabled by default.
    --skip-oci-image
        Build artifacts but do not create the image
    --skip-digest-generation
        Write image entries as is instead of re-writing with digests
"

function print_usage() {
    echo -e "$USAGE"
}

function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -t|--tag)
            TAG="$2"
            shift; shift;
            ;;
            -r|--registry)
            REGISTRY="$2"
            shift; shift;
            ;;
            -o|--organization)
            ORGANIZATION="$2"
            shift; shift;
            ;;
            --offline)
            BUILD_FLAGS_ARRAY+=("--embed-vsix:true")
            shift;
            ;;
            --skip-oci-image)
            SKIP_OCI_IMAGE="true"
            shift;
            ;;
            --skip-digest-generation)
            BUILD_FLAGS_ARRAY+=("--skip-digest-generation:true")
            shift;
            ;;
            *)
            print_usage
            exit 0
        esac
    done
}

parse_arguments "$@"

echo "Update yarn dependencies..."
yarn
echo "Generate artifacts..."
ECPRG_VER=$(curl -sSLo- https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/crw-2.11-rhel-8/dependencies/VERSION.json | \
jq -r '.Other["@eclipse-che/plugin-registry-generator"]["2.11"]');
npx @eclipse-che/plugin-registry-generator@"${ECPRG_VER}" --root-folder:"$(pwd)" --output-folder:"$(pwd)/output" "${BUILD_FLAGS_ARRAY[@]}"

echo -e "\nTest entrypoint.sh"
EMOJI_HEADER="-" EMOJI_PASS="[PASS]" EMOJI_FAIL="[FAIL]" "${base_dir}"/build/dockerfiles/test_entrypoint.sh

if [ "${SKIP_OCI_IMAGE}" != "true" ]; then
    BUILD_COMMAND="build"
    # Tar up the outputted files as the Dockerfile depends on them
    tar -czvf resources.tgz ./output/v3/
    if [[ -z $BUILDER ]]; then
        echo "BUILDER not specified, trying with podman"
        BUILDER=$(command -v podman || true)
        if [[ ! -x $BUILDER ]]; then
            echo "[WARNING] podman is not installed, trying with buildah"
            BUILDER=$(command -v buildah || true)
            if [[ ! -x $BUILDER ]]; then
                echo "[WARNING] buildah is not installed, trying with docker"
                BUILDER=$(command -v docker || true)
                if [[ ! -x $BUILDER ]]; then
                    echo "[ERROR] neither docker, buildah, nor podman are installed. Aborting"; exit 1
                fi
            else
                BUILD_COMMAND="bud"
            fi
        fi
    else
        if [[ ! -x $(command -v "$BUILDER" || true) ]]; then
            echo "Builder $BUILDER is missing. Aborting."; exit 1
        fi
        if [[ $BUILDER =~ "docker" || $BUILDER =~ "podman" ]]; then
            if [[ ! $($BUILDER ps) ]]; then
                echo "Builder $BUILDER is not functioning. Aborting."; exit 1
            fi
        fi
        if [[ $BUILDER =~ "buildah" ]]; then
            BUILD_COMMAND="bud"
        fi
    fi
    echo "Building with $BUILDER $BUILD_COMMAND"
    IMAGE="${REGISTRY}/${ORGANIZATION}/pluginregistry-rhel8:${TAG}"
    # Copy to root directory to behave as if in Brew or codeready-workspaces-images
    cp "${DOCKERFILE}" ./builder.Dockerfile
    ${BUILDER} ${BUILD_COMMAND} -t "${IMAGE}" -f ./builder.Dockerfile .
    # Remove copied Dockerfile and tarred zip
    rm ./builder.Dockerfile resources.tgz
fi
