#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# for a given image+sha, compute the associated tag

imageAndSHA=$1
if [[ -z $1 ]]; then 
    echo "Usage: $0 registry/org/image@sha256:digest"
    exit 1
fi
echo "For $imageAndSHA"
image=${imageAndSHA%%@*}
URL=$(skopeo inspect docker://${imageAndSHA} | jq -r '.Labels.url')
# echo "Got $URL"
container=${URL}
container=${image}:${container##*/images/}
echo "Got $container"
# skopeo inspect docker://${container} | jq -r .Digest # note, this might be different from the input SHA, but still equivalent 

