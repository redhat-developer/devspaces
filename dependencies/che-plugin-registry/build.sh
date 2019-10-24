#!/bin/bash
#
# Copyright (c) 2012-2018 Red Hat, Inc.
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
LATEST_ONLY=false
OFFLINE=false
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
    --latest-only
        Build registry to only contain 'latest' meta.yamls; default: 'false'
    --offline
        Build offline version of registry, with all extension artifacts
        cached in the registry; disabled by default.
    --rhel
        Build using the rhel.Dockerfile instead of the default
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
            --latest-only)
            LATEST_ONLY=true
            shift
            ;;
            --offline)
            OFFLINE=true
            shift
            ;;
            --rhel)
            DOCKERFILE=./build/dockerfiles/rhel.Dockerfile
            shift
            ;;
            *)
            print_usage
            exit 0
        esac
    done
}

parse_arguments "$@"

IMAGE="${REGISTRY}/${ORGANIZATION}/che-plugin-registry:${TAG}"
echo -n "Building image '$IMAGE' "
if [ "$OFFLINE" = true ]; then
    echo "in offline mode"
    docker build \
        -t "$IMAGE" \
        -f "$DOCKERFILE" \
        --build-arg LATEST_ONLY="${LATEST_ONLY}" \
        --target offline-registry .
else
    echo ""
    docker build \
        -t "$IMAGE" \
        -f "$DOCKERFILE" \
        --build-arg LATEST_ONLY="${LATEST_ONLY}" \
        --target registry .
fi
