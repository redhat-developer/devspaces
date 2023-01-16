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
ALLOWED_TAGS=""
while [[ "$#" -gt 0 ]]; do
	case $1 in
		'--registries') ALLOWED_REGISTRIES="${ALLOWED_REGISTRIES} $2"; shift 1;;
		'--tags') ALLOWED_TAGS="${ALLOWED_TAGS} $2"; shift 1;;
		*) if [[ $target_dir == "" ]]; then target_dir="$1"; fi;;
	esac
	shift 1
done

if [[ $ALLOWED_REGISTRIES ]] || [[ $ALLOWED_TAGS ]]; then 
    had_failure=0
    script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    containers=$("${script_dir}/list_referenced_images.sh" "$target_dir")
    containers_all=$("${script_dir}/list_referenced_images_by_file.sh" "$target_dir")
fi

# if no registries set, then all registries are allowed
if [[ $ALLOWED_REGISTRIES ]] && [[ $ALLOWED_REGISTRIES != " " ]]; then 
    for container in $containers; do
        check_passed=""
        for registry in $ALLOWED_REGISTRIES; do
            if [[ $container == "$registry/"* ]]; then
                check_passed="$registry"
            fi
        done
        if [[ $check_passed != "" ]]; then
            echo " + $container PASS - $check_passed allowed"
        else
            echo " - $container FAIL - not in allowed registries: '$ALLOWED_REGISTRIES'"
            echo -n " - "
            echo "$containers_all" | grep -E "$container" | sed -r -e "s#\t# :: #g" \
                -e "s#(http.+github.com/)(.+)(/devfile.yaml)#<a href=\1\2\3>\2</a>#" | sort -uV || true
                # shellcheck disable=SC2219
            let had_failure=had_failure+1
        fi
    done
fi

# if no tags set, then all tags are allowed
if [[ $ALLOWED_TAGS ]] && [[ $ALLOWED_TAGS != " " ]]; then
    for container in $containers; do
        check_passed=""
        for tag in $ALLOWED_TAGS; do
            if [[ $container == *"/devspaces/"*":$tag" ]]; then
                check_passed="$tag"
            elif [[ $container == *"/jboss-eap"* ]] || [[ $container == *"/mongodb"* ]]; then
                check_passed="$container"
            fi
        done
        if [[ $check_passed == "$container" ]]; then
            echo " = $container PASS"
        elif [[ $check_passed != "" ]]; then
            echo " + $container PASS - $check_passed allowed"
        else
            echo " - $container FAIL - not in allowed tags: '$ALLOWED_TAGS'"
            echo -n " - "
            echo "$containers_all" | grep -E "$container" | sed -r -e "s#\t# :: #g" \
                -e "s#(http.+github.com/)(.+)(/devfile.yaml)#<a href=\1\2\3>\2</a>#" | sort -uV || true
            # shellcheck disable=SC2219
            let had_failure=had_failure+1
        fi
    done
fi

# shellcheck disable=SC2086
if [[ $had_failure -gt 0 ]]; then exit $had_failure; fi
