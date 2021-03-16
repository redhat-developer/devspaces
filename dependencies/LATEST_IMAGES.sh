#!/bin/bash
#
# Copyright (c) 2020-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to generate simple digests of latest images, image commits, and image digests
# REQUIRES: 
#    * skopeo >=1.1 (for authenticated registry queries, and to use --override-arch for s390x images)
#    * jq to do json queries
#    * yq to do yaml queries inside getLatestImageTags.sh (install the python3 wrapper for jq using pip)
# 
# https://registry.redhat.io is v2 and requires authentication to query, so login in first like this:
# docker login registry.redhat.io -u=USERNAME -p=PASSWORD

command -v skopeo >/dev/null 2>&1 || { echo "skopeo is not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is not installed. Aborting."; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "yq is not installed. Aborting."; exit 1; }
checkVersion() {
  if [[  "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]]; then
    # echo "[INFO] $3 version $2 >= $1, can proceed."
	true
  else 
    echo "[ERROR] Must install $3 version >= $1"
    exit 1
  fi
}
checkVersion 1.1 "$(skopeo --version | sed -e "s/skopeo version //")" skopeo

# STEP 1 :: regenerate image tag list in LATEST_IMAGES
./product/getLatestImageTags.sh --quay --sort | tee dependencies/LATEST_IMAGES

# STEP 2 :: # regenerate image set digests (not the per-arch digests) from list of LATEST_IMAGES
# requires skopeo >= 1.1 for the --override-arch flag
echo '{' > dependencies/LATEST_IMAGES_DIGESTS.json
echo '    "Images": {' >> dependencies/LATEST_IMAGES_DIGESTS.json
for d in $(cat dependencies/LATEST_IMAGES); do
  archOverride=""
  if [[ ${d} = *"-openj9-"* ]]; then 
    archOverride="--override-arch s390x"
  fi
  if [[ ${d} != *":???" ]]; then
    digest=$(skopeo inspect docker://${d} ${archOverride}| jq -r '.Digest' | sed -r -e "s/sha256://" 2>/dev/null)
    echo "${d} ==> ${digest}"
    echo "        \"${d}\": \"${digest}\"," >> dependencies/LATEST_IMAGES_DIGESTS.json
  else 
    echo "${d} ==> n/a"
  fi
done
{ 
  echo '        "": ""';
  echo '    }';
  echo '}'; 
} >> dependencies/LATEST_IMAGES_DIGESTS.json
# NOTE: can fetch the sha256sum digest for a given image set (not the per-arch digests) with this:
# jq -r '.Images | to_entries[] | select (.key == "quay.io/crw/machineexec-rhel8:2.8-2") | .value' LATEST_IMAGES_DIGESTS.json

# STEP 3 :: regenerate commit info in LATEST_IMAGES_COMMITS
rm -f dependencies/LATEST_IMAGES_COMMITS
for d in $(cat dependencies/LATEST_IMAGES); do 
  ./product/getCommitSHAForTag.sh ${d} | tee -a dependencies/LATEST_IMAGES_COMMITS
done

# now commit changes
