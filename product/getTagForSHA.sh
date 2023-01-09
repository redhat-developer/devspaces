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

usage () {
	echo "Usage:   ${0##*/} $0 registry/org/image@sha256:digest [OPTIONS]

Options:
  -y, --quay    search for image on quay.io registry if not found on provided one (eg., for an unreleased registry.redhat.io image)
  -q, --quiet   quieter output
  -h, --help    this help
"
}

if [[ $# -lt 1 ]]; then usage; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-y'|'--quay')  imageAndSHAs="${imageAndSHAs} quay.io/${imageAndSHAs#*/}";;
    '-q'|'--quiet') QUIET=1;;
    '-h'|'--help')  usage; exit 0;;
    *)              imageAndSHAs="${imageAndSHAs} $1";;
  esac
  shift 1
done

for imageAndSHA in $imageAndSHAs; do
    if [[ $QUIET -eq 0 ]]; then echo "For $imageAndSHA"; fi
    image=${imageAndSHA%%@*}
    URL=$(skopeo inspect docker://${imageAndSHA} | jq -r '.Labels.url')
    # echo "Got $URL"
    if [[ $URL ]]; then
        container=${URL}
        container=${image}:${container##*/images/}
        if [[ $QUIET -eq 0 ]]; then echo "Got $container"; else echo $container; fi
    else
        if [[ $2 == "--quay" ]]; then 
            echo "Not found"; echo
        else 
            echo; echo "Not found; try --quay flag to check same image on quay.io registry"
        fi
    fi
    # skopeo inspect docker://${container} | jq -r .Digest # note, this might be different from the input SHA, but still equivalent 
done
