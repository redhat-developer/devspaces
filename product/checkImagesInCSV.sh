#!/bin/bash
#
# Copyright (c) 2022-2023 Red Hat, Inc.
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
# by default resolve image tags / digests from RHEC or as stated in the CSV; with this override, check Brew if can't find in RHEC
BREW=0
# by default, show the tag :: image@sha; optionally just show image:tag
QUIET=0
# by default show all images; optionally filter for one or more, eg 'devfile|plugin|udi'
REGEX_FILTER=""

# defaults to pass to getLatestIIBs.sh
OCP_VER=""
GLI_FLAG=""

# compute a default value for PROD_VER to use in usage()
PROD_VER="3.yy"
if [[ -f dependencies/job-config.json ]]; then
	jcjson=dependencies/job-config.json
else
	jcjson=/tmp/job-config.json
	curl -sSLo $jcjson https://raw.githubusercontent.com/redhat-developer/devspaces/devspaces-3-rhel-8/dependencies/job-config.json
fi
PROD_VER=$(jq -r '.Version' $jcjson)
# cleanup /tmp files
rm -fr /tmp/job-config.json || true

usage () {
  echo "
Usage:
  Using a specific bundle: $0 bundle-image1 [bundle-image2...] [OPTIONS]
  Using the latest bundle: $0 -t $PROD_VER -o 4.12 [OPTIONS]

Options:
  -t <product tag>     Use getLatestIIBs.sh to fetch latest IIB's contained bundle image, 
  -o <OCP version>     and check that bundle's CSV; BOTH these are required.
  --ds, --dwo, --wto   Define which product defaults to use; if not set, assume --ds.

  -y, --quay           If image not resolved from RH Ecosystem Catalog, check equivalent image on quay.io
  --brew               If image not resolved from RH Ecosystem Catalog, check equivalent image on brew.registry.redhat.io
  -i, --filter         Rather than return ALL images in the build, include a subset using grep -E
  -q, --quiet          Quiet output: show 'image:tag' instead of default 'tag :: image@sha'
  -qq, --quieter       Quieter output: omit everything but related images

Examples:
  $0 quay.io/devspaces/devspaces-operator-bundle:$PROD_VER -y -i 'dashboard|operator|registry-rhel|udi'

To compare latest image in Quay to latest CSV in bundle in latest IIB:
  TAG=$PROD_VER; \\
  IMG=devspaces/dashboard-rhel8; \\
  IMG=devspaces/devfileregistry-rhel8; \\
  img_quay=\$(${SCRIPTPATH}/getLatestImageTags.sh -b devspaces-\${TAG}-rhel-8 --quay --tag \"\${TAG}\" -c \${IMG}); echo \$img_quay; \\
  img_iib=\$(${SCRIPTPATH}/checkImagesInCSV.sh --ds -t \${TAG} -o 4.12 -y -qq -i \${IMG}); echo \$img_iib; \\
  if [[ \$img_quay != \$img_iib ]]; then \\
    ${SCRIPTPATH}/checkImagesInCSV.sh --ds -t \${TAG} -o 4.12 -y -i \${IMG}; \\
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
    '--brew') BREW=1; shift 0;;
    '-i'|'--filter') REGEX_FILTER="$2"; shift 1;;
    '-q'|'--quiet') QUIET=1; shift 0;;
    '-qq'|'--quieter') QUIET=2; shift 0;;
    *) IMAGES="${IMAGES} $1"; shift 0;;
  esac
  shift 1
done

if [[ $PROD_VER ]] && [[ $PROD_VER != "3.yy" ]] && [[ $OCP_VER ]] && [[ ! $IMAGES ]]; then # compute latest IIB -> bundle
  if [[ $QUIET -lt 2 ]]; then
    echo "Checking for latest OCP v${OCP_VER} IIB for ${GLI_FLAG//--} ${PROD_VER}"
  fi
  if [[ $QUIET -lt 2 ]]; then
    "${SCRIPTPATH}"/getLatestIIBs.sh -t "${PROD_VER}" -o "${OCP_VER}" "${GLI_FLAG}"
  fi
  if [[ $QUIET -lt 2 ]]; then
    echo "----------"
  fi
  # use getLatestImageTags.sh instead of getLatestIIBs.sh as it's more reliable when datagrepper content is unavailable/expired
  GLIT=${SCRIPTPATH}/getLatestImageTags.sh
  if [[ $GLI_FLAG == "--dwo" ]]; then
    IMAGES=$(${GLIT} --osbs -c devworkspace-operator-bundle --tag "${PROD_VER}")
  elif [[ $GLI_FLAG == "--ds" ]]; then
    IMAGES=$(${GLIT} --osbs -c devspaces-operator-bundle --tag "${PROD_VER}")
  else
    echo "ERROR: only Dev Spaces and Dev Workspace operators are supported by this tool."
    exit 2
  fi
fi

# echo "REGEX_FILTER = $REGEX_FILTER"

# shellcheck disable=SC2086
for imageAndTag in $IMAGES; do 
    SOURCE_CONTAINER=${imageAndTag%%:*}
    containerTag=$(skopeo inspect docker://${imageAndTag} | jq -r '.Labels.url' | sed -r -e "s#.+/images/##")
    # echo "Found containerTag = ${containerTag}"

    if [[ ! -x ${SCRIPTPATH}/containerExtract.sh ]]; then
        curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/devspaces-3-rhel-8/product/containerExtract.sh
        chmod +x containerExtract.sh
    fi
    rm -fr /tmp/${SOURCE_CONTAINER//\//-}-${containerTag}-*/
    "${SCRIPTPATH}"/containerExtract.sh ${SOURCE_CONTAINER}:${containerTag} --delete-before --delete-after >/dev/null 2>&1 || true
    related_images=$(cat /tmp/${SOURCE_CONTAINER//\//-}-${containerTag}-*/manifests/*.{csv,clusterserviceversion}.yaml 2>/dev/null | grep sha256: | sed -r -e "s@.+(value|mage\"*): @@" -e "s@\"(.+)\".+@\1@" | sort -uV)
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
              # CRW-3330 support publishing DWO images from brew.reg or reg-proxy
              elif [[ $BREW -eq 1 ]]; then # check brew registry
                # NOTE: could use registry-proxy.engineering.redhat.com/rh-osbs/ instead but that's internal facing, 
                # where brew.reg is auth'd and public
                # convert registry.redhat.io/devworkspace/devworkspace-rhel8-operator
                # to      brew.registry.redhat.io/rh-osbs/devworkspace-operator
                related_image=$(echo $related_image | sed -r -e "s#registry.redhat.io/.+/#brew.registry.redhat.io/rh-osbs/#" -e "s#-rhel8##g")
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
