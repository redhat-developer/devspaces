#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# this script requires podman and yq

QUIET=""

usage() {
  echo "
This script will attempt to extract a list of related images from the ClusterServiceVersion (CSV) 
of the DevWorkspace operator bundle and the Dev Spaces (or Eclipse Che) operator bundle. 

For Che Operator: https://github.com/redhat-openshift-ecosystem/community-operators-prod/tree/main/operators/eclipse-che/
For Dev Workspace Operator: https://quay.io/repository/devworkspace/devworkspace-operator-bundle?tab=tags
For Dev Spaces Operator: https://quay.io/repository/devspaces/devspaces-operator-bundle?tab=tags

Usage: 
  $0 -t VERSION -d DWO_VERSION [-q]

Example:
    $0 -t 3.3 -d 0.17 -q      # devspaces, quiet output
    $0 -t 7.56.0 -d 0.16      # che, normal output
"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') VERSION="$2"; shift 1;;
    '-d') DWO_VERSION="$2"; shift 1;;
    '-q') QUIET="--quiet";;
    '-h') usage;;
  esac
  shift 1
done
if [[ ! $VERSION ]] || [[ ! $DWO_VERSION ]]; then usage; exit 1; fi

TMPDIR=`mktemp -d`; cd $TMPDIR
if [[ ! -f /tmp/containerExtract.sh ]]; then
    curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/devspaces-3-rhel-8/product/containerExtract.sh
else
    cp /tmp/containerExtract.sh $TMPDIR/
fi
chmod +x $TMPDIR/*.sh
EXTRACT_CMD="$TMPDIR/containerExtract.sh $QUIET --tmpdir $TMPDIR --delete-before --delete-after"

# 1. fetch CSV related images for Che or DS bundle
if [[ $VERSION == "7."* ]] || [[ $VERSION == "8."* ]]; then # che
    CSV=https://raw.githubusercontent.com/redhat-openshift-ecosystem/community-operators-prod/main/operators/eclipse-che/${VERSION}/manifests/eclipse-che.v${VERSION}.clusterserviceversion.yaml
    curl -sSLo $TMPDIR/che.csv.yaml $CSV
    yq -r '.spec.relatedImages[].image' $TMPDIR/che.csv.yaml | sort -uV
elif [[ $VERSION == "3."* ]] || [[ $VERSION == "4."* ]]; then # ds
    rm -fr $TMPDIR/quay.io-*-devspaces-operator-bundle-${VERSION}-* || true
    ${EXTRACT_CMD} quay.io/devspaces/devspaces-operator-bundle:${VERSION} 
    CSV=$(find $TMPDIR/quay.io-*-devspaces-operator-bundle-${VERSION}-*/manifests/ -name "*csv.yaml")
    if [[ $QUIET == "" ]]; then echo "[INFO] Checking CSV: $CSV"; fi
    yq -r '.spec.relatedImages[].image' "${CSV}" | sort -uV
    if [[ $QUIET == "" ]]; then echo; fi
else 
    echo "[ERROR] Invalid version for Che or Dev Spaces"; exit 2
fi

# 2. fetch CSV related images for downstream DWO bundle
rm -fr $TMPDIR/quay.io-*-devworkspace-operator-bundle-${DWO_VERSION} || true
${EXTRACT_CMD} quay.io/devworkspace/devworkspace-operator-bundle:${DWO_VERSION}
CSV=$(find $TMPDIR/quay.io-*-devworkspace-operator-bundle-${DWO_VERSION}-*/manifests/ -name "*clusterserviceversion.yaml")
if [[ $QUIET == "" ]]; then echo "[INFO] Checking CSV: $CSV"; fi
yq -r '.spec.relatedImages[].image' "${CSV}" | sort -uV
if [[ $QUIET == "" ]]; then echo; fi

# cleanup
cd /tmp
rm -fr $TMPDIR
