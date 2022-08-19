#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# verify that if we're building a stable branch build, we don't
# have quay.io references (only RH Ecosystem Catalog references)
# pass in space-separated list of acceptable registries
set -e

target_dir=""
ALLOWED_REGISTRIES=""
while [[ "$#" -gt 0 ]]; do
	case $1 in
		*) if [[ $target_dir == "" ]]; then target_dir="$1"; else ALLOWED_REGISTRIES="${ALLOWED_REGISTRIES} $1"; fi;;
	esac
	shift 1
done

# if no registries set, then all registries are allowed
if [[ $ALLOWED_REGISTRIES ]]; then 
    had_failure=0
    script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    containers=$(${script_dir}/list_referenced_images.sh $target_dir)
    for container in $containers; do
        registry_passed=""
        for registry in $ALLOWED_REGISTRIES; do
            if [[ $container == "$registry/"* ]]; then
                registry_passed="$registry"
            fi
        done
        if [[ $registry_passed != "" ]]; then
            echo " + $container PASS - $registry_passed allowed"
        else
            echo " - $container FAIL - not in allowed registries: '$ALLOWED_REGISTRIES'"
            had_failure=1
        fi
    done
    if [[ $had_failure -eq 1 ]]; then exit 1; fi
fi
