#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# script to query latest IIBs (one per OCP version) for a given version of CRW

usage () {
	echo "
Usage: 
  $0 -t CRW_VERSION
"
}

runCommandWithTimeout() {
  this_timeout=$1
  count=1
  (( timeout_intervals=this_timeout/5 ))
  while [[ $count -le $timeout_intervals ]]; do # echo $count
    set +e
    echo "       [$count/$timeout_intervals] Attempting to resolve IIBs..." 
    lastcsv=$(curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=30&contains=devspaces" | \
      jq ".raw_messages[].msg.index | .added_bundle_images[0]" -r | sort -uV | grep "${csv}:${CRW_VERSION}" | tail -1 | \
      sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/devspaces-##");

    iibs=$(curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=30&contains=devspaces" | \
      jq ".raw_messages[].msg.index | [.added_bundle_images[0], .index_image, .ocp_version] | @tsv" -r | sort -uV | \
      grep "${lastcsv}" | sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/devspaces-#  #"; )
    if [[ $iibs ]]; then
       echo $images;
       break;
    fi
    (( count=count+1 ))
    sleep 300s
  done
    # or report an error
    if [[ !$? -eq 0 ]]; then
        echo "[ERROR] Did not get IIBs after ${this_timeout} minutes - script must exit!"
        exit 1;
    fi
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') CRW_VERSION="$2"; shift 1;;
  esac
  shift 1
done

if [[ -z ${CRW_VERSION} ]]; then usage; exit 1; fi

CSVs="operator-bundle" # 2.16+
if [[ $CRW_VERSION == "2.15" ]]; then CSVs="operator-metadata operator-bundle"; fi

echo "Checking for latest IIBs for CRW ${CRW_VERSION} ..."; echo
for csv in $CSVs; do
  runCommandWithTimeout 30
done

