#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to skopeo copy some image to quay (preserving multiple arches)
# will compute tag from sha if only a sha is provided.

# must be logged in to the source and target registries to read from and copy to

# eg., registry.stage.redhat.io/devworkspace/devworkspace-operator-bundle@sha256:ffd00fff23ee87d09dea8cea5b1c649b62a85db30cca645ada2bf0a53c39e375
# to   quay.io/devworkspace/devworkspace-operator-bundle:0.15-3.1661828401

usage () {
    echo "Usage: $0 registry/org/image:tag1 registry/org/image2@sha256:...  -v (verbose output)

Example: $0 -v registry.stage.redhat.io/devworkspace/devworkspace-operator-bundle@sha256:ffd00fff23ee87d09dea8cea5b1c649b62a85db30cca645ada2bf0a53c39e375 ..."
}

# TODO: optionally set other tags if we pass in PUSHTOQUAYTAGS, eg., "latest" or "next" 
PUSHTOQUAYTAGS=""

VERBOSE=0
if [[ "$#" -eq 0 ]]; then usage; exit 1; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-v') VERBOSE=1;;
    '-h') usage; exit 1;;
    --pushtoquay=*) PUSHTOQUAYTAGS="$(echo "${1#*=}")";;
    *) images="$images $1"
  esac
  shift 1
done

for image in $images; do
    IMG=$image
    if [[ $image =~ (.+)@sha256:(.+) ]]; then 
        IMG=${BASH_REMATCH[1]}
        URL=$(skopeo inspect docker://${image} | jq -r '.Labels.url')
        container=${URL}
        container=${IMG}:${container##*/images/}
        image=${container}
        if [[ $VERBOSE -eq 1 ]]; then 
            SHA=${BASH_REMATCH[2]}
            echo "Got image $image from $IMG @ $SHA"
        fi
    else
        image=${IMG#*/}
    fi
    TAG=${image##*:}
    REGISTRYPRE=${IMG%%/*}/
    if [[ $IMG =~ .+(rh-osbs/|devworkspace/|devspaces/).+ ]]; then REGISTRYPRE="${REGISTRYPRE}${BASH_REMATCH[1]}"; fi
    URLfrag=${image#*/}

    QUAYDEST="${URLfrag}"; 
    # # special case for the operator and bundle images, which don't follow the same pattern in osbs as quay
    if [[ $URLfrag == *"devworkspace"* ]]; then
        if [[ ${QUAYDEST} =~ .*(devworkspace-|)project-clone(-rhel8|):.+ ]];   then QUAYDEST="devworkspace/devworkspace-project-clone-rhel8:${TAG}"; fi
        if [[ ${QUAYDEST} =~ .*(devworkspace-|)operator-bundle:.+ ]];          then QUAYDEST="devworkspace/devworkspace-operator-bundle:${TAG}"; fi
        if [[ ${QUAYDEST} =~ .*(devworkspace-|)(rhel8-|)operator:.+ ]];        then QUAYDEST="devworkspace/devworkspace-rhel8-operator:${TAG}"; fi
    elif [[ $URLfrag == *"devspaces"* ]]; then
        if [[ ${QUAYDEST} == *"/operator-bundle:"* ]]; then QUAYDEST="devspaces/devspaces-operator-bundle:${TAG}"; fi
        if [[ ${QUAYDEST} == *"/operator:"* ]];        then QUAYDEST="devspaces/devspaces-rhel8-operator:${TAG}"; fi
    else
        # replace /rh-osbs/foo-image with foo/image
        QUAYDEST=$(echo $QUAYDEST | sed -r -e "s#rh-osbs/([^-])-#\1/#g")
    fi
    QUAYDEST="quay.io/${QUAYDEST}"

    if [[ $VERBOSE -eq 1 ]]; then
        echo "Source: $REGISTRYPRE $URLfrag"
        echo "Target: $QUAYDEST"
    fi

    if [[ $(skopeo --insecure-policy inspect docker://${QUAYDEST} 2>&1) == *"Error"* ]]; then 
        # CRW-1914 copy tag ONLY if it doesn't already exist on the registry, to prevent re-timestamping it and making it look new
        if [[ $VERBOSE -eq 1 ]]; then echo "Copy ${REGISTRYPRE}${URLfrag} to ${QUAYDEST}"; fi
        CMD="skopeo --insecure-policy copy --all docker://${REGISTRYPRE}${URLfrag} docker://${QUAYDEST}"; echo $CMD; $CMD
    else
        if [[ $VERBOSE -eq 1 ]]; then echo "Copy ${QUAYDEST} - already exists, nothing to do"; fi
    fi

    # and update additional PUSHTOQUAYTAGS tags 
    for qtag in ${PUSHTOQUAYTAGS}; do
        if [[ $(skopeo --insecure-policy inspect docker://${QUAYDEST%:*}:${qtag} 2>&1) == *"Error"* ]]; then 
            if [[ $VERBOSE -eq 1 ]]; then echo "Copy ${REGISTRYPRE}${URLfrag} to ${QUAYDEST%:*}:${qtag}"; fi
            CMD="skopeo --insecure-policy copy --all docker://${REGISTRYPRE}${URLfrag} docker://${QUAYDEST%:*}:${qtag}"; echo $CMD; $CMD
        else
            if [[ $VERBOSE -eq 1 ]]; then echo "Copy ${QUAYDEST%:*}:${qtag} - already exists, nothing to do"; fi
        fi
    done
done
