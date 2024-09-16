#!/bin/bash
#
# Copyright (c) 2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# for a given IIB container, check the RELATED_IMAGE's digests align to specific images

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")

# by default resolve image tags / digests from RHEC or as stated in the CSV; with this override, check Quay if can't find in RHEC
QUAY=""
# by default resolve image tags / digests from RHEC or as stated in the CSV; with this override, check Brew if can't find in RHEC
BREW=""
# by default, show the tag :: image@sha; optionally just show image:tag
QUIET=""
QUIETER=""
# by default show all images; optionally filter for one or more, eg 'dashboard|plugin|udi'
REGEX_FILTER=""

usage () {
  echo "For a given IIB container, check that the bundle image's RELATED_IMAGE's digests align to specific images

Requires:
* jq 1.6+, yq, sudo
* opm v1.26.3+ (see https://docs.openshift.com/container-platform/4.12/cli_reference/opm/cli-opm-install.html#cli-opm-install )

Usage:
  Using a specific IIB: $0 bundle-image1 [OPTIONS]

Options:
  -y, --quay           If image not resolved from RH Ecosystem Catalog, check equivalent image on quay.io
  --brew               If image not resolved from RH Ecosystem Catalog, check equivalent image on brew.registry.redhat.io
  -i, --filter         Rather than return ALL images in the build, include a subset using grep -E
  -q, --quiet          Quiet output: show fewer steps
  -qq, --quieter       Quieter output: omit everything but related images

Examples:
  $0 brew.registry.redhat.io/rh-osbs/iib-pub-pending:v4.12 --brew --quay --filter 'dashboard|operator|registry-rhel|udi' --quiet
  $0 quay.io/devspaces/iib:3.5-v4.13-x86_64  --quay --filter 'dashboard|operator|registry-rhel' -qq
"
}

if [[ $# -lt 1 ]]; then usage; exit; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-y'|'--quay') QUAY="--quay"; shift 0;;
    '--brew') BREW="--brew"; shift 0;;
    '-i'|'--filter') REGEX_FILTER="$2"; shift 1;;
    '-q'|'--quiet') QUIET="--quiet"; shift 0;;
    '-qq'|'--quieter') QUIET="--quiet"; QUIETER="true"; shift 0;;
    *) IMAGES="${IMAGES} $1"; shift 0;;
  esac
  shift 1
done

for IIB_IMAGE in $IMAGES; do
    IMAGE_PATH=${IIB_IMAGE//\//-}; IMAGE_PATH=${IMAGE_PATH//:/-}
    rm -fr /tmp/"${IMAGE_PATH}"-*/ 2>/dev/null || sudo rm -fr /tmp/"${IMAGE_PATH}"-*/ 2>/dev/null  || true
    "${SCRIPTPATH}"/containerExtract.sh --delete-before --delete-after "${QUIET}" "${IIB_IMAGE}"
    cd /tmp/"${IMAGE_PATH}"-* || exit 1

    # for newer file-based catalogs like OCP 4.12
    catalogJson="configs/devspaces/catalog.json"

    # for older database catalogs like OCP 4.10
    if [[ -d database ]]; then 
        if [[ $QUIETER != "true" ]]; then echo "[INFO] Converting index.db to configs folder"; fi
        pushd database >/dev/null || exit 1
        if [[ $QUIETER == "true" ]]; then 
            opm migrate index.db ../configs 1>/dev/null 2>/dev/null
        elif [[ $QUIET == "--quiet" ]]; then
            opm migrate index.db ../configs 2>/dev/null
        else 
            opm migrate index.db ../configs
        fi
        popd >/dev/null || exit 1
    elif [[ -f configs/devspaces/channel.json ]]; then # for quay.io/devspaces/iib 
        catalogJson="configs/devspaces/channel.json"
    fi
    if [[ ! -f $catalogJson ]]; then echo "[ERROR] Could not read $(pwd)/$catalogJson ! Must exit."; exit 1; fi

    # latest CSV bundle
    #    "schema": "olm.bundle",
    #    "name": "devspacesoperator.v3.4.0",
    bundle=$(grep '"schema": "olm.bundle"' -A1 $catalogJson | tail -1 | sed -r -e 's@.+name": "(.+)".*@\1@')
    # alternative query for quay.io/devspaces/iib containers
    if [[ ! $bundle ]]; then
        bundle=$(grep '"name":' $catalogJson | tail -1 | sed -r -e 's@.+name": "(.+)".*@\1@')
    fi

    if [[ $QUIETER != "true" ]]; then echo "[INFO] Bundle Version: $bundle"; fi
    #  "image": "registry.stage.redhat.io/devspaces/devspaces-operator-bundle@sha256:481491c923cb9b432b23f4bd6f64599d82180b2ed1c7f558bc1f8335256c64e3",
    imageWithSHA=$(grep "${bundle}" -A2 $catalogJson | grep image | sed -r -e 's@.+image": "(.+)".+@\1@')
    # alternative query for quay.io/devspaces/iib containers
    if [[ ! $imageWithSHA ]]; then # instead of channel.json or catalog.json, use devspacesoperator.v3.5.0.bundle.json
        imageWithSHA=$(grep '"schema": "olm.bundle"' -A3 ${catalogJson/channel.json/${bundle}.bundle.json} | tail -1 | sed -r -e 's@.+image": "(.+)".+@\1@')
    fi

    if [[ $QUIETER != "true" ]]; then echo "[INFO] Bundle Image SHA: $imageWithSHA"; fi
    # Got quay.io/devspaces/devspaces-operator-bundle:3.4-170
    bundleContainers=$("${SCRIPTPATH}"/getTagForSHA.sh "${imageWithSHA}" ${QUAY} "${QUIET}")
    # extract the last value or the failure (tokenize to remove "For..." and "Got..." if we're not in quiet mode)
    bundleContainer=""
    for bc in $bundleContainers; do bundleContainer=$bc; done 
    if [[ $QUIETER != "true" ]]; then echo "[INFO] Bundle Image Tag: $bundleContainer"; 
        if [[ $REGEX_FILTER ]]; then 
            echo "[INFO] CSV contains [filter = $REGEX_FILTER]:"
        else
        echo "[INFO] CSV contains:"
        fi
    fi
    "${SCRIPTPATH}/checkImagesInCSV.sh" "${bundleContainer}" ${QUAY} "${QUIET}" ${BREW} -i "$REGEX_FILTER"
done
