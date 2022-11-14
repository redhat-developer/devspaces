#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
# 
# The script is used by GitHub PR check action "VSIX Definition PR Check", 
# it validates the IDs of VS Code extensions from openvsx-sync.json file 

trap EXIT

RED="\e[31m"
GREEN="\e[32m"
RESETSTYLE="\e[0m"
BOLD="\e[1m"
DEFAULT_EMOJI_HEADER="🏃" # could be overiden with EMOJI_HEADER="-"
EMOJI_HEADER=${EMOJI_HEADER:-$DEFAULT_EMOJI_HEADER}
DEFAULT_EMOJI_PASS="✔" # could be overriden with EMOJI_PASS="[PASS]"
EMOJI_PASS=${EMOJI_PASS:-$DEFAULT_EMOJI_PASS}
DEFAULT_EMOJI_FAIL="✘" # could be overriden with EMOJI_FAIL="[FAIL]"
EMOJI_FAIL=${EMOJI_FAIL:-$DEFAULT_EMOJI_FAIL}

function initTest() {
    echo -e "${BOLD}\n${EMOJI_HEADER} ${1}${RESETSTYLE}"
}

echo -e "${BOLD}\n${EMOJI_HEADER}${EMOJI_HEADER}${EMOJI_HEADER} Validate content of openvsx_sync.json: ${BASH_SOURCE[0]}${RESETSTYLE}"

################################################################
openVsxSyncFileContent=$(cat "../../../openvsx-sync.json")
numberOfExtensions=$(echo "${openVsxSyncFileContent}" | jq ". | length")
echo "The number of extensions is $numberOfExtensions"
IFS=$'\n' 

for i in $(seq 0 "$((numberOfExtensions - 1))"); do
    vsixFullName=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].id")
    initTest "Checking $vsixFullName"

    # id should be set 
    if [[ $vsixFullName == null ]] || [[ -z "$vsixFullName" ]]; then
      echo -e "ID of the extension with number $i wasn't set"
      echo -e "${RED}${EMOJI_FAIL}${RESETSTYLE} Test failed!"
      exit 1
    fi
    
    vsixDownloadLink=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].download")
    vsixVersion=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].version")

    # version should not be empty if download link was set
    if [[ $vsixDownloadLink != null ]] && [[ -z "$vsixVersion" ]]; then
      echo -e "Version should not be empty for $vsixFullName"
      echo -e "${RED}${EMOJI_FAIL}${RESETSTYLE} Test failed!"
      exit 1
    fi
    
    # version should be set if download link was set
    if [[ $vsixDownloadLink != null ]] && [[ $vsixVersion == null ]]; then
      echo -e "Version is not defined for $vsixFullName"
      echo -e "${RED}${EMOJI_FAIL}${RESETSTYLE} Test failed!"
      exit 1
    fi
    
    # Publisher and name should be divided by . in extension's id
    # extract from the vsix name the publisher name which is the first part of the vsix name before dot
    vsixPublisher=${vsixFullName%.*}
    # extract from the vsix name the extension name which is the second part of the vsix name after dot
    vsixName=${vsixFullName##*.}
    if [[ $vsixFullName != *.* ]] || [[ -z "$vsixPublisher" ]] || [[ -z "$vsixName" ]]; then
      echo -e "Publisher and name should be divided by . for $vsixFullName"
      echo -e "${RED}${EMOJI_FAIL}${RESETSTYLE} Test failed!"
      exit 1
    fi

done;

echo -e "${GREEN}${EMOJI_PASS}${RESETSTYLE} The content is valid!"
