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

# access created date and digest with 
# $➔ jq -r '.Images["quay.io/crw/pluginbroker-artifacts-rhel8:2.13-2"].Digest' dependencies/LATEST_IMAGES_DIGESTS.json 
# 8b6063b116a78a6886e4e1afc836c5f7d03ce010d58af7b426dce4293d60cf25
# $➔ jq -r '.Images["quay.io/crw/pluginbroker-artifacts-rhel8:2.13-2"].Created' dependencies/LATEST_IMAGES_DIGESTS.json 
# 2021-10-09T01:49:17.048651536Z

COMMIT_CHANGES=0

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

for key in "$@"; do
  case $key in 
      '--commit') COMMIT_CHANGES=1; shift 1;;
  esac
done

if [[ -f dependencies/VERSION ]]; then
  VERSION=$(cat dependencies/VERSION)
fi

# try to compute branches from currently checked out branch; else fall back to hard coded value
DWNSTM_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ $DWNSTM_BRANCH != "crw-2."*"-rhel-8" ]] && [[ $DWNSTM_BRANCH != "crw-2-rhel-8" ]]; then
	DWNSTM_BRANCH="crw-${VERSION}-rhel-8"
fi

# STEP 1 :: regenerate image tag list in LATEST_IMAGES
CMD="./product/getLatestImageTags.sh --quay -b ${DWNSTM_BRANCH} --tag ${VERSION}- --hide"
# shellcheck disable=SC2086
echo $CMD
$CMD | tee dependencies/LATEST_IMAGES

# STEP 2 :: # regenerate image set digests (not the per-arch digests) from list of LATEST_IMAGES
# requires skopeo >= 1.1 for the --override-arch flag
echo '{' > dependencies/LATEST_IMAGES_DIGESTS.json
echo '    "Images": {' >> dependencies/LATEST_IMAGES_DIGESTS.json
# shellcheck disable=SC2013
for d in $(cat dependencies/LATEST_IMAGES); do
  archOverride="--override-arch amd64"
  if [[ ${d} = *"-openj9-"* ]]; then 
    archOverride="--override-arch ppc64le"
  fi
  if [[ ${d} != *":???" ]]; then
  # shellcheck disable=SC2086
    digestAndCreatedTime=$(skopeo inspect docker://${d} ${archOverride}| jq -r '[.Digest, .Created] | @csv' | sed -r -e "s/sha256://" 2>/dev/null)
    digest=${digestAndCreatedTime%%,*}
    createdTime=${digestAndCreatedTime##*,}
    echo "${d} ==> ${digest}, ${createdTime}"
    echo "        \"${d}\": {\"Digest\": ${digest}, \"Created\": ${createdTime}}," >> dependencies/LATEST_IMAGES_DIGESTS.json
  fi
done

{ 
  # empty array item to prevent json validation error for trailing comma
  echo '        "": {"Digest":"", "Created":""}' 
  echo '    }'
  echo '}'
} >> dependencies/LATEST_IMAGES_DIGESTS.json

# STEP 3 :: regenerate commit info in LATEST_IMAGES_COMMITS
rm -f dependencies/LATEST_IMAGES_COMMITS
# shellcheck disable=SC2013
for d in $(cat dependencies/LATEST_IMAGES); do 
  # shellcheck disable=SC2086
  ./product/getCommitSHAForTag.sh ${d} -b ${DWNSTM_BRANCH} | tee -a dependencies/LATEST_IMAGES_COMMITS
done
# add an extra line to avoid linelint errors, ffs.
echo "." >> dependencies/LATEST_IMAGES_COMMITS

if [[ ${COMMIT_CHANGES} -eq 1 ]]; then
  # CRW-1621 if any gz resources are larger than 10485760b, must use MaxFileSize to force dist-git to shut up and take my sources!
  if [[ $(git commit -s -m "chore: Update dependencies/LATEST_IMAGES, COMMITS, DIGESTS" dependencies/LATEST_IMAGES* || true) == *"nothing to commit, working tree clean"* ]]; then
    echo "[INFO] No changes to commit."
  else
    git status -s -b --ignored
    echo "[INFO] Push change:"
    git config pull.rebase true
    git config push.default matching
    git pull; git push
  fi
fi
