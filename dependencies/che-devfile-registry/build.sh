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
CONTAINERNAME="che-devfile-registry"
TAG="nightly"
TARGET="registry" # or offline-registry
USE_DIGESTS=false
DOCKERFILE="./build/dockerfiles/Dockerfile"
PODMAN="" # by default, use docker

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
    --builder
        Create a dev image for building this registry. See also devfile.yaml.
    --podman
        Use podman instead of docker
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
            shift 2
            ;;
            -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
            -o|--organization)
            ORGANIZATION="$2"
            shift 2
            ;;
            -c|--container)
            CONTAINERNAME="$2"
            shift 2
            ;;
            --use-digests)
            USE_DIGESTS=true
            shift
            ;;
            --offline)
            TARGET="offline-registry"
            shift
            ;;
            --builder)
            TARGET="builder"
            shift
            ;;
            --rhel)
            DOCKERFILE="./build/dockerfiles/rhel.Dockerfile"
            shift
            ;;
            '--podman')
            PODMAN=$(which podman 2>/dev/null || true)
            shift
            ;;
            *)
            print_usage
            exit 0
        esac
    done
}

parse_arguments "$@"

# to build with podman if present, use --podman flag, else use docker
DOCKER="docker"; if [[ ${PODMAN} ]]; then DOCKER="${PODMAN}"; fi

IMAGE="${REGISTRY}/${ORGANIZATION}/${CONTAINERNAME}:${TAG}"
VERSION=$(head -n 1 VERSION)
case $VERSION in
  *SNAPSHOT)
    echo "Snapshot version (${VERSION}) specified in $(find . -name VERSION): building nightly plugin registry."
    ${DOCKER} build \
        -t "${IMAGE}" \
        -f ${DOCKERFILE} \
        --build-arg "USE_DIGESTS=${USE_DIGESTS}" \
        --target "${TARGET}" .
    ;;
  *)
    echo "Release version specified in $(find . -name VERSION): Building plugin registry for release ${VERSION}."
    ${DOCKER} build \
        -t "${IMAGE}" \
        -f "${DOCKERFILE}" \
        --build-arg "PATCHED_IMAGES_TAG=${VERSION}" \
        --build-arg "USE_DIGESTS=${USE_DIGESTS}" \
        --target "${TARGET}" .
    ;;
esac
