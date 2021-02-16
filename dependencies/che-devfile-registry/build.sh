#!/bin/bash
#
# Copyright (c) 2019-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

set -e

REGISTRY="quay.io"
ORGANIZATION="eclipse"
TAG="nightly"
TARGET="registry" # or offline-registry
USE_DIGESTS=false
DOCKERFILE="./build/dockerfiles/Dockerfile"

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
    --use-digests
        Build registry to use images pinned by digest instead of tag
    --offline
        Build offline version of registry, with all artifacts included
        cached in the registry; disabled by default.
    --rhel
        Build using the rhel.Dockerfile (UBI images) instead of default
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
            --use-digests)
            USE_DIGESTS=true
            shift
            ;;
            --offline)
            TARGET="offline-registry"
            shift
            ;;
            --rhel)
            DOCKERFILE="./build/dockerfiles/rhel.Dockerfile"
            shift
            ;;
            *)
            print_usage
            exit 0
        esac
    done
}

parse_arguments "$@"

BUILD_COMMAND="build"
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

IMAGE="${REGISTRY}/${ORGANIZATION}/che-devfile-registry:${TAG}"
VERSION=$(head -n 1 VERSION)
case $VERSION in
  *SNAPSHOT)
    echo "Snapshot version (${VERSION}) specified in $(find . -name VERSION): building nightly plugin registry."
    ${BUILDER} ${BUILD_COMMAND} \
        -t "${IMAGE}" \
        -f ${DOCKERFILE} \
        --build-arg "USE_DIGESTS=${USE_DIGESTS}" \
        --target "${TARGET}" .
    ;;
  *)
    echo "Release version specified in $(find . -name VERSION): Building plugin registry for release ${VERSION}."
    ${BUILDER} ${BUILD_COMMAND} \
        -t "${IMAGE}" \
        -f "${DOCKERFILE}" \
        --build-arg "PATCHED_IMAGES_TAG=${VERSION}" \
        --build-arg "USE_DIGESTS=${USE_DIGESTS}" \
        --target "${TARGET}" .
    ;;
esac
