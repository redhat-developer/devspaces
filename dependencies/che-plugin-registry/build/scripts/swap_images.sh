#!/bin/bash
#
# Copyright (c) 2020-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

# script common to devfileregistry and pluginregistry; see also crw-operator/build/scripts/swap_images.sh

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)

USE_GENERATED_CONTENT=0
FORCE_SWAP=0
arch="$(uname -m)"

while [[ "$#" -gt 0 ]]; do
  case $1 in
  '--use-generated-content') USE_GENERATED_CONTENT=1;;
  '-f') FORCE_SWAP=1;; # force transformation even on an incompatible architecture for testing purposes
  '-a') arch="$2"; shift 1;;
  *) YAML_ROOT="$1";;
  esac
  shift 1
done

if [[ $USE_GENERATED_CONTENT -eq 1 ]]; then
    cheYamls=$("$SCRIPT_DIR"/list_yaml.sh "$YAML_ROOT")
else
    cheYamls=$("$SCRIPT_DIR"/list_che_yaml.sh "$YAML_ROOT")
fi

# shellcheck disable=SC2086
if [[ "$arch" != "x86_64" ]] || [[ $FORCE_SWAP -eq 1 ]]; then
    echo -n "[INFO] swap openjdk for openj9 images on $arch"
    if [[ $FORCE_SWAP -eq 1 ]]; then echo -n " (forced)"; fi
    echo
    for yaml in $cheYamls; do
        sed -E -i 's|plugin-java8-rhel8|plugin-java8-openj9-rhel8|g' "$yaml"
        sed -E -i 's|plugin-java11-rhel8|plugin-java11-openj9-rhel8|g' "$yaml"
    done
else
    echo "[INFO] nothing to do on $arch; only swap openjdk for openj9 images on s390x and ppc64le arches"
fi
