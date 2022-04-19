#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# for a given metadata or bundle container, check the RELATED_IMAGE's digests align to specific images

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")

# by default resolve image tags / digests from RHEC or as stated in the CSV; with this override, check Quay if can't find in RHEC
QUAY=0

usage () {
  echo "
Usage:   $0 bundle-image1 [bundle-image2...]

Examples:
Check images in RHEC only: $0 quay.io/crw/crw-2-rhel8-operator-bundle:2.15-276.1647377069
Check Quay if not in RHEC: $0 quay.io/devspaces/devspaces-operator-bundle:3.0 --quay
"
}

if [[ $# -lt 1 ]]; then usage; exit; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--quay') QUAY=1; shift 0;;
    *) IMAGES="${IMAGES} $1"; shift 0;;
  esac
  shift 1
done

for imageAndTag in $IMAGES; do 
    SOURCE_CONTAINER=${imageAndTag%%:*}
    containerTag=$(skopeo inspect docker://${imageAndTag} | jq -r '.Labels.url' | sed -r -e "s#.+/images/##")
    # echo "Found containerTag = ${containerTag}"

    if [[ ! -x ${SCRIPTPATH}/containerExtract.sh ]]; then
        curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/devspaces-3-rhel-8/product/containerExtract.sh
        chmod +x containerExtract.sh
    fi
    rm -fr /tmp/${SOURCE_CONTAINER//\//-}-${containerTag}-*/
    ${SCRIPTPATH}/containerExtract.sh ${SOURCE_CONTAINER}:${containerTag} --delete-before --delete-after 2>&1 >/dev/null || true
    related_images=$(cat /tmp/${SOURCE_CONTAINER//\//-}-${containerTag}-*/manifests/*.csv.yaml | grep sha256: | sed -re "s@.+(value|mage): @@" | sort -uV)
    for related_image in $related_images; do 
        # check each image digest to compute matching tag
        jqdump="$(skopeo inspect docker://${related_image} 2>&1)"
        if [[ $jqdump == *"Labels"* ]]; then 
            tag=$(echo $jqdump | jq -r '.Labels.url' | sed -r -e "s#.+/images/##")
        else
            if [[ $QUAY -eq 1 ]]; then # check quay
              related_image=${related_image//registry.redhat.io/quay.io}
              jqdump="$(skopeo inspect docker://${related_image} 2>&1)"
              if [[ $jqdump == *"Labels"* ]]; then 
                  tag=$(echo $jqdump | jq -r '.Labels.url' | sed -r -e "s#.+/images/##")
              fi
            else 
                tag="NOT FOUND!"
            fi
        fi
        echo "$tag :: $related_image"
    done
done