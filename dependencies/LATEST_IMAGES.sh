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
# $➔ jq -r '.Images["quay.io/devspaces/pluginbroker-artifacts-rhel8:2.13-2"].Digest' dependencies/LATEST_IMAGES_DIGESTS.json 
# 8b6063b116a78a6886e4e1afc836c5f7d03ce010d58af7b426dce4293d60cf25
# $➔ jq -r '.Images["quay.io/devspaces/pluginbroker-artifacts-rhel8:2.13-2"].Created' dependencies/LATEST_IMAGES_DIGESTS.json 
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
if [[ $DWNSTM_BRANCH != "devspaces-3."*"-rhel-8" ]] && [[ $DWNSTM_BRANCH != "devspaces-3-rhel-8" ]]; then
	DWNSTM_BRANCH="devspaces-${VERSION}-rhel-8"
fi

# STEP 1 :: regenerate image tag list in LATEST_IMAGES
CMD="./product/getLatestImageTags.sh --quay -b ${DWNSTM_BRANCH} --tag ${VERSION} --hide"
# shellcheck disable=SC2086
echo $CMD
$CMD | tee dependencies/LATEST_IMAGES

# STEP 2 :: regenerate IIB listings into LATEST_IMAGES_INDEXES.json
echo '{' > dependencies/LATEST_IMAGES_INDEXES.json
echo '    "Indexes": {' >> dependencies/LATEST_IMAGES_INDEXES.json

for opmetbun in operator-bundle; do 
  for d in $(cat dependencies/LATEST_IMAGES | grep -E "${opmetbun}"); do
    BUNDLE_TAG=${d##*:} # quay.io/devspaces/devspaces-operator-bundle:2.15-153 ==> 2.15-153
    # compute internal OSBS image path, eg. registry-proxy.engineering.redhat.com/rh-osbs/devspaces-operator-bundle:2.15-153
    BUNDLE_OSBS=${d##quay.io/devspaces/}
    # echo "BUNDLE_TAG  = $BUNDLE_TAG"
    # echo "BUNDLE_OSBS = $BUNDLE_OSBS"

    # NOTE datagrepper is paginated, may need to select a different page than 1 here
    results=$(curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=100&contains=devspaces&page=1" | \
    jq ".raw_messages[].msg.index | [.added_bundle_images[0], .index_image, .ocp_version] | @csv" -r | sort -uV | \
    grep "${BUNDLE_OSBS}" | sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/devspaces-##" | tr -d "\"")
    echo '        "'${opmetbun}'": {' >> dependencies/LATEST_IMAGES_INDEXES.json
    echo '            "'${VERSION}'": {' >> dependencies/LATEST_IMAGES_INDEXES.json # devspaces version
    for row in $results; do
      IFS=',' read -r -a cols <<< "$row"
      # echo "operator-bundle[$VERSION][${cols[2]}] = { ${cols[0]}, ${cols[1]} }"
      iibTag=${cols[1]};iibTag=${iibTag##*:}
      echo '                "'${cols[2]}'": {' >> dependencies/LATEST_IMAGES_INDEXES.json # ocp version
      echo '                    "iibURL": "'${cols[1]}'",' >> dependencies/LATEST_IMAGES_INDEXES.json # ocp version
      echo '                    "iibTag": "'${iibTag}'"' >> dependencies/LATEST_IMAGES_INDEXES.json # ocp version
      echo '                },' >> dependencies/LATEST_IMAGES_INDEXES.json # ocp version
    done
    echo '                "OSBSImage": "'registry-proxy.engineering.redhat.com/rh-osbs/devspaces-${BUNDLE_OSBS}'",' >> dependencies/LATEST_IMAGES_INDEXES.json # ocp version
    echo '                "quayImage": "'${d}'",' >> dependencies/LATEST_IMAGES_INDEXES.json # ocp version
    echo '                "tag": "'${BUNDLE_TAG}'"' >> dependencies/LATEST_IMAGES_INDEXES.json # ocp version
    echo '            }' >> dependencies/LATEST_IMAGES_INDEXES.json # devspaces version
    echo '        }' >> dependencies/LATEST_IMAGES_INDEXES.json # operator-bundle
  done
done
{ 
  # empty array item to prevent json validation error for trailing comma
  echo '    }' # Indexes
  echo '}'
} >> dependencies/LATEST_IMAGES_INDEXES.json
# collect iib tag for OCP 4.9 index
# $➔ jq -r '.Indexes["operator-bundle"]["2.15"]["v4.9"].iibTag' dependencies/LATEST_IMAGES_INDEXES.json
# collect all iibTags
# $➔ jq -r '.Indexes["operator-bundle"]["2.15"][] | select (.|objects) | .iibTag' dependencies/LATEST_IMAGES_INDEXES.json

# STEP 3 :: # regenerate image set digests (not the per-arch digests) from list of LATEST_IMAGES
# requires skopeo >= 1.1 for the --override-arch flag
echo '{' > dependencies/LATEST_IMAGES_DIGESTS.json
echo '    "Images": {' >> dependencies/LATEST_IMAGES_DIGESTS.json
# shellcheck disable=SC2013
for d in $(cat dependencies/LATEST_IMAGES); do
  archOverride="--override-arch amd64"
  if [[ ${d} != *":???" ]]; then
  # shellcheck disable=SC2086
    digestAndCreatedTime=$(skopeo inspect docker://${d} ${archOverride}| jq -r '[.Digest, .Created] | @csv' | sed -r -e "s/sha256://" 2>/dev/null)
    digest=${digestAndCreatedTime%%,*}
    createdTime=${digestAndCreatedTime##*,}
    if [[ ! $digest ]]; then digest='""'; fi
    if [[ ! $createdTime ]]; then createdTime='""'; fi
    echo "${d} ==> ${digest}, ${createdTime}"
    echo "        \"${d}\": {\"Created\": ${createdTime}, \"Digest\": ${digest}, \"Image\": \"${d}\"}," >> dependencies/LATEST_IMAGES_DIGESTS.json
  fi
done

{ 
  # empty array item to prevent json validation error for trailing comma
  echo '        "": {"Created":"", "Digest":"", "Image":""}' 
  echo '    }'
  echo '}'
} >> dependencies/LATEST_IMAGES_DIGESTS.json
# collect latest timestamps by build with
# $➔ cat dependencies/LATEST_IMAGES_DIGESTS.json | jq -r '.Images[] | select(.Created != "") | (.Created +"\t"+ .Image)'|sort -uV

# STEP 4 :: regenerate commit info in LATEST_IMAGES_COMMITS
rm -f dependencies/LATEST_IMAGES_COMMITS
# shellcheck disable=SC2013
for d in $(cat dependencies/LATEST_IMAGES); do 
  # shellcheck disable=SC2086
  ./product/getCommitSHAForTag.sh ${d} -b ${DWNSTM_BRANCH} | tee -a dependencies/LATEST_IMAGES_COMMITS
  cat dependencies/LATEST_IMAGES_COMMITS | grep NVR | sed -r -e "s#.+NVR: ##" > dependencies/LATEST_IMAGES_NVRS
done

# STEP 5 :: update OSBS performance data
echo 
for d in $(cat dependencies/LATEST_IMAGES_COMMITS | grep Build | sed -r -e s@.+buildID=@@); do
  ./product/collectBuildInfo.sh -b $d --append -f dependencies/LATEST_BUILD_TIMES.yml --csv dependencies/LATEST_BUILD_TIMES.csv
done

if [[ ${COMMIT_CHANGES} -eq 1 ]]; then
  # CRW-1621 if any gz resources are larger than 10485760b, must use MaxFileSize to force dist-git to shut up and take my sources!
  git add dependencies/LATEST_* || true
  if [[ $(git commit -s -m "chore: Update dependencies/LATEST_IMAGES, COMMITS, DIGESTS, INDEXES, BUILD_TIMES" dependencies/LATEST_IMAGES* dependencies/LATEST_BUILD_TIMES* || true) == *"nothing to commit, working tree clean"* ]]; then
    echo "[INFO] No changes to commit."
  else
    git status -s -b --ignored
    echo "[INFO] Push change:"
    git config pull.rebase true
    git config push.default matching
    git pull; git push
  fi
fi
