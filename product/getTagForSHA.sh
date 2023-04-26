#!/bin/bash
#
# Copyright (c) 2021-2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# for a given image+sha, compute the associated tag
# optionally, use --quay flag to also check quay.io registry

QUIET=0
USE_QUAY="false" # check for image at quay.io, if not found
USE_QUAY_TOO="false" # always check for image at quay.io
usage () {
	echo "Usage:   ${0##*/} $0 registry/org/image@sha256:digest [OPTIONS]

Options:
  -y, --quay       search for image on quay.io registry if not found on provided one (eg., for an unreleased registry.redhat.io image)
  -yy, --quay-too  search for image on quay.io registry AS WELL AS on provided one (eg., to compare RHEC Freshmaker releases w/ Quay.io ones)
  -q, --quiet      quieter output - only container name found
  -h, --help       this help
"
}

if [[ $# -lt 1 ]]; then usage; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-y'|'--quay')       USE_QUAY=true;;
    '-yy'|'--quay-too')  USE_QUAY="true"; USE_QUAY_TOO=true;;
    '-q'|'--quiet')      QUIET=1;;
    '-h'|'--help')       usage; exit 0;;
    *)                   imageAndSHAs="${imageAndSHAs} $1";;
  esac
  shift 1
done

checkImage_result=""
checkImage () {
    checkImage_result=""
    local imageAndSHA="$1"
    if [[ $QUIET -eq 0 ]]; then echo "For $imageAndSHA"; fi
    image=${imageAndSHA%%@*}
    # echo "[DEBUG] Got image = $image"
    # shellcheck disable=SC2086
    if [[ $QUIET -eq 1 ]]; then 
        URL=$(skopeo inspect docker://${imageAndSHA} 2>/dev/null | jq -r '.Labels.url')
    else
        URL=$(skopeo inspect docker://${imageAndSHA} | jq -r '.Labels.url')
    fi
    # echo "[DEBUG] Got URL = $URL"
    if [[ $URL ]]; then
        container=${URL}
        container=${image}:${container##*/images/}
        # replace quay.io/devspaces/devspaces-rhel8-operator:3.4:3.4-22 with quay.io/devspaces/devspaces-rhel8-operator:3.4-22
        container=$(echo "$container" | sed -r -e "s@:[0-9.]+:@:@")
        if [[ $QUIET -eq 0 ]]; then echo "Got $container"; else echo "$container"; fi
        checkImage_result="true"
    else
        if [[ ${imageAndSHA} == "quay.io/"* ]];then 
            echo "Not found"
        elif [[ $USE_QUAY != "true" ]]; then 
            echo "Not found; try --quay or -y flag to check same image on quay.io registry"
        fi
        if [[ "$USE_QUAY" == "true" ]]; then
            checkImage_result="false"
        fi
    fi
    # skopeo inspect docker://${container} | jq -r .Digest # note, this might be different from the input SHA, but still equivalent 
}

for imageAndSHA in $imageAndSHAs; do
    checkImage "${imageAndSHA}"
    if [[ "$checkImage_result" == "false" ]] || [[ "$USE_QUAY_TOO" == "true" ]]; then
        if [[ "${imageAndSHA}" != "quay.io/"* ]]; then # don't check quay again if we already did!
            quayImage="${imageAndSHA#*/}"
            # transform brew rh-osbs/foo-operator to quay foo/foo-operator
            quayImage="$(echo "$quayImage" | sed -r -e "s@rh-osbs/([^-]+)-(.+)@\1/\1-\2@")"
            checkImage "quay.io/${quayImage}"
        fi
    fi
done
