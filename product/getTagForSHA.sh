#!/bin/bash
#
# Copyright (c) 2021-2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# for a given image+sha, compute the associated tag
# optionally, use --quay flag to also check quay.io registry

if [[ -z $1 ]]; then 
    echo "Usage: $0 registry/org/image@sha256:digest [--quay]"
    echo
    echo "Use --quay flag to search for image on quay.io registry if not found on provided one (eg., for an unreleased registry.redhat.io image)"
    exit 1
fi
imageAndSHAs=$1
if [[ $2 == "--quay" ]]; then 
    imageAndSHAs="${imageAndSHAs} quay.io/${imageAndSHAs#*/}"
fi
for imageAndSHA in $imageAndSHAs; do
    echo "For $imageAndSHA"
    image=${imageAndSHA%%@*}
    URL=$(skopeo inspect docker://${imageAndSHA} | jq -r '.Labels.url')
    # echo "Got $URL"
    if [[ $URL ]]; then
        container=${URL}
        container=${image}:${container##*/images/}
        echo "Got $container"
    else
        if [[ $2 == "--quay" ]]; then 
            echo "Not found"; echo
        else 
            echo; echo "Not found; try --quay flag to check same image on quay.io registry"
        fi
    fi
    # skopeo inspect docker://${container} | jq -r .Digest # note, this might be different from the input SHA, but still equivalent 
done
