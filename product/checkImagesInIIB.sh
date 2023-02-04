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
# by default show all images; optionally filter for one or more, eg 'devfile|plugin|udi'
REGEX_FILTER=""

usage () {
  echo "For a given IIB container, check that the bundle image's RELATED_IMAGE's digests align to specific images

Requires:
* jq 1.6+, yq, sudo
* opm v1.19.5+ (see https://docs.openshift.com/container-platform/4.11/cli_reference/opm/cli-opm-install.html#cli-opm-install )

Usage:
  Using a specific IIB: $0 bundle-image1 [OPTIONS]

Options:
  -y, --quay           If image not resolved from RH Ecosystem Catalog, check equivalent image on quay.io
  --brew               If image not resolved from RH Ecosystem Catalog, check equivalent image on brew.registry.redhat.io
  -i, --filter         Rather than return ALL images in the build, include a subset using grep -E
  -q                   Quieter output: show 'image:tag' instead of default 'tag :: image@sha'
  -qq                  Even quieter output: omit everything but related images

Example:
  $0 brew.registry.redhat.io/rh-osbs/iib-pub-pending:v4.10 -y -i 'operator|bundle'
"
}

if [[ $# -lt 1 ]]; then usage; exit; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-y'|'--quay') QUAY="--quay"; shift 0;;
    '--brew') BREW="--brew"; shift 0;;
    '-i'|'--filter') REGEX_FILTER="$2"; shift 1;;
    '-q') QUIET="--quiet"; shift 0;;
    *) IMAGES="${IMAGES} $1"; shift 0;;
  esac
  shift 1
done

for IIB_IMAGE in $IMAGES; do
    IMAGE_PATH=${IIB_IMAGE//\//-}; IMAGE_PATH=${IMAGE_PATH//:/-}
    rm -fr /tmp/"${IMAGE_PATH}"-*/ 2>/dev/null || sudo rm -fr /tmp/"${IMAGE_PATH}"-*/ 2>/dev/null  || true
    "${SCRIPTPATH}"/containerExtract.sh --delete-before --delete-after ${QUIET} "${IIB_IMAGE}"
    cd /tmp/"${IMAGE_PATH}"-*/database/ || exit 1
    opm migrate index.db migrated

    # latest CSV bundle
    #    "schema": "olm.bundle",
    #    "name": "devspacesoperator.v3.4.0",
    bundle=$(grep '"schema": "olm.bundle"' -A1 migrated/devspaces/catalog.json | tail -1 | sed -r -e 's@.+name": "(.+)".*@\1@')
    #  "image": "registry.stage.redhat.io/devspaces/devspaces-operator-bundle@sha256:481491c923cb9b432b23f4bd6f64599d82180b2ed1c7f558bc1f8335256c64e3",
    imageWithSHA=$(grep "${bundle}" -A2 migrated/devspaces/catalog.json | grep image | sed -r -e 's@.+image": "(.+)".+@\1@')
    # Got quay.io/devspaces/devspaces-operator-bundle:3.4-170
    bundleContainers=$("${SCRIPTPATH}"/getTagForSHA.sh "${imageWithSHA}" ${QUAY} ${QUIET})
    # extract the last value or the failure (tokenize to remove "For..." and "Got..." if we're not in quiet mode)
    bundleContainer=""
    for bc in $bundleContainers; do bundleContainer=$bc; done 
    "${SCRIPTPATH}/checkImagesInCSV.sh" "${bundleContainer}" ${QUAY} ${QUIET} ${BREW} -i "$REGEX_FILTER"
done
