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

REGISTRY="quay.io"
ORGANIZATION="crw"
CONTAINERNAME="devfileregistry-rhel8"
TAG="next"
TARGET="registry" # or offline-registry
DOCKERFILE="./build/dockerfiles/Dockerfile"

USAGE="
Usage: ./build.sh [OPTIONS]
Options:
    --help
        Print this message.
    --tag, -t [TAG]
        Docker image tag to be used for image; default: 'next'
    --registry, -r [REGISTRY]
        Docker registry to be used for image; default 'quay.io'
    --organization, -o [ORGANIZATION]
        Docker image organization to be used for image; default: 'crw'
    --offline
        Build offline version of registry, with all artifacts included
        cached in the registry; disabled by default.
    --builder
        Create a dev image for building this registry. See also devfile.yaml.
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
            --offline)
            TARGET="offline-registry"
            shift
            ;;
            --builder)
            TARGET="builder"
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

IMAGE="${REGISTRY}/${ORGANIZATION}/${CONTAINERNAME}:${TAG}"
${BUILDER} ${BUILD_COMMAND} \
    -t "${IMAGE}" \
    -f ${DOCKERFILE} \
    --target "${TARGET}" .
