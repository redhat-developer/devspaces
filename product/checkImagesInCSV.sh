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
# by default, show the tag :: image@sha; optionally just show image:tag
QUIET=0
# by default show all images; optionally filter for one or more, eg 'devfile|plugin|udi'
REGEX_FILTER=""

# defaults to pass to getLatestIIBs.sh
PROD_VER=""
OCP_VER=""
GLI_FLAG=""

usage () {
  echo "
Usage:
  Using a specific bundle: $0 bundle-image1 [bundle-image2...] [OPTIONS]
  Using the latest bundle: $0 -t 3.1 -o 4.10 [OPTIONS]

Options:
  -t <product tag>     Use getLatestIIBs.sh to fetch latest IIB's contained bundle image, 
  -o <OCP version>     and check that bundle's CSV; BOTH these are required.
  --ds, --dwo, --wto   Define which product defaults to use; if not set, assume --ds.

  -y, --quay           If image not resolved from RH Ecosystem Catalog, check equivalent image on Quay
  -i, --filter         Rather than return ALL images in the build, include a subset using grep -E
  -q                   Quieter output: show 'image:tag' instead of default 'tag :: image@sha'
  -qq                  Even quieter output: omit everything but related images

Examples:
  $0 quay.io/crw/crw-2-rhel8-operator-bundle:2.15-276.1647377069
  $0 quay.io/devspaces/devspaces-operator-bundle:3.1 -y -i 'devfile|plugin|udi'

To compare latest image in Quay to latest CSV in bundle in latest IIB:
  TAG=3.1; \\
  IMG=devspaces/dashboard-rhel8; \\
  IMG=devspaces/devfileregistry-rhel8; \\
  img_quay=\$(${SCRIPTPATH}/getLatestImageTags.sh -b devspaces-\${TAG}-rhel-8 --quay --tag \"\${TAG}-\" -c \${IMG}); echo \$img_quay; \\
  img_iib=\$(${SCRIPTPATH}/checkImagesInCSV.sh --ds -t \${TAG} -o 4.11 -y -qq -i \${IMG}); echo \$img_iib; \\
  if [[ \$img_quay != \$img_iib ]]; then \\
    ${SCRIPTPATH}/checkImagesInCSV.sh --ds -t \${TAG} -o 4.11 -y -i \${IMG}; \\
  fi
"
}

if [[ $# -lt 1 ]]; then usage; exit; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--crw'|'--ds'|'--dwo'|'--wto') GLI_FLAG="$1"; shift 0;;
    '-t') PROD_VER="$2"; shift 1;;
    '-o') OCP_VER="$2"; shift 1;;
    '-y'|'--quay') QUAY=1; shift 0;;
    '-i'|'--filter') REGEX_FILTER="$2"; shift 1;;
    '-q') QUIET=1; shift 0;;
    '-qq') QUIET=2; shift 0;;
    *) IMAGES="${IMAGES} $1"; shift 0;;
  esac
  shift 1
done

if [[ $PROD_VER ]] && [[ $OCP_VER ]] && [[ ! $IMAGES ]]; then # compute latest IIB -> bundle
  if [[ $QUIET -lt 2 ]]; then
    echo "Checking for latest OCP v${OCP_VER} IIB for ${GLI_FLAG//--} ${PROD_VER}"
  fi
  if [[ $QUIET -lt 2 ]]; then
    ${SCRIPTPATH}/getLatestIIBs.sh -t ${PROD_VER} -o ${OCP_VER} ${GLI_FLAG}
  fi
  if [[ $QUIET -lt 2 ]]; then
    echo "----------"
  fi
  IMAGES=$(${SCRIPTPATH}/getLatestIIBs.sh -t ${PROD_VER} -o ${OCP_VER} -qb)
fi

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
        if [[ $REGEX_FILTER ]]; then related_image=$(echo "$related_image" | grep -E "$REGEX_FILTER"); fi
        if [[ "${related_image}" ]]; then
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
          if [[ $QUIET -gt 0 ]]; then
            echo "${related_image%@sha256*}:$tag"
          else
            echo "$tag :: $related_image"
          fi
        fi
    done
done
