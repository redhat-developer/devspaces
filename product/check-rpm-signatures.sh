#!/bin/bash -ex
#
# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
# check for unsigned images in list of NVRs

SCRIPT_DIR=$(pwd)
if [[ -d ${WORKSPACE} ]]; then 
    TMPDIR="${WORKSPACE}"
else
    TMPDIR=$(mktemp -d)
fi
mkdir -p "${TMPDIR}"; cd "${TMPDIR}" || exit
# get script
curl -sSLO http://download.devel.redhat.com/scripts/rel-eng/utility/snippets/check-image-rpm-sigs.sh && chmod +x check-image-rpm-sigs.sh

command -v jq >/dev/null 2>&1 || { echo "jq is not installed. Aborting."; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "jq is not installed. Aborting."; exit 1; }

DWNSTM_BRANCH="crw-2.8-rhel-8"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-b') DWNSTM_BRANCH="$2"; shift 1;; 
  esac
  shift 1
done

# get latest NVRs
"${SCRIPT_DIR}"/getLatestImageTags.sh -b "${DWNSTM_BRANCH}" --nvr | tee "${TMPDIR}"/nvrs.list.txt

# switch to use docker executable in check-image-rpm-sigs.sh script, if podman is not installed
command -v podman >/dev/null 2>&1 || { sudo yum install -y podman; }

rm -f "${SCRIPT_DIR}"/missing.signatures.txt
for NVR in $(cat "${TMPDIR}"/nvrs.list.txt); do
  "${TMPDIR}"/check-image-rpm-sigs.sh ${NVR} | tee "${TMPDIR}"/${NVR}.signatures.txt
  unsigned=$(cat "${TMPDIR}"/${NVR}.signatures.txt | jq '.images[] | to_entries | map_values(.value + { rpm: .key }) | .[] | select(.timestamp == "").rpm' -r | sort | uniq | grep -v gpg-pubkey- || true)

  if [[ ${unsigned} ]]; then
    echo "[ERROR] Found unsigned RPMs in ${NVR}:" | tee -a "${SCRIPT_DIR}"/missing.signatures.txt
    echo "${unsigned}" | tee -a "${SCRIPT_DIR}"/missing.signatures.txt
    echo | tee -a "${SCRIPT_DIR}"/missing.signatures.txt
  fi
done

echo "[INFO] Missing RPM signatures logged to: "
echo "${SCRIPT_DIR}"/missing.signatures.txt
echo
echo "[INFO] Additional temporary files in ${TMPDIR}"
