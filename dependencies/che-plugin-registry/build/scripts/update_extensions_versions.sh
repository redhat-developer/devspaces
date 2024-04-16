#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# The script checks the available versions from openvsx.org 
# and updates them in the list of extensions that are going to be included into the embedded plugin registry

trap EXIT

set -e
set -o pipefail

GREEN="\e[32m"
RESETSTYLE="\e[0m"
BOLD="\e[1m"
DEFAULT_EMOJI_HEADER="🏃" # could be overiden with EMOJI_HEADER="-"
EMOJI_HEADER=${EMOJI_HEADER:-$DEFAULT_EMOJI_HEADER}
DEFAULT_EMOJI_PASS="✔" # could be overriden with EMOJI_PASS="[PASS]"
EMOJI_PASS=${EMOJI_PASS:-$DEFAULT_EMOJI_PASS}
DEFAULT_EMOJI_FAIL="✘" # could be overriden with EMOJI_FAIL="[FAIL]"
EMOJI_FAIL=${EMOJI_FAIL:-$DEFAULT_EMOJI_FAIL}

function initMessage() {
  echo -e "${BOLD}\n${EMOJI_HEADER} ${1}${RESETSTYLE}"
}

echo -e "${BOLD}\n${EMOJI_HEADER}${EMOJI_HEADER}${EMOJI_HEADER} Check new versions for extensions from openvsx_sync.json: ${BASH_SOURCE[0]}${RESETSTYLE}"

# Get version of the editor
scriptBranch=$(git rev-parse --abbrev-ref HEAD)
echo "Dev Spaces version=${scriptBranch}"
codeVersion=$(curl -sSlko- https://raw.githubusercontent.com/redhat-developer/devspaces-images/"${scriptBranch}"/devspaces-code/code/package.json | jq -r '.version')
echo "Che Code version=${codeVersion}"

# Check if the information about the current branch is empty
if [[ -z "$scriptBranch" ]]; then
  echo -e "The branch is not defined. It is not possible to get Che Code version."
  exit 1
fi

################################################################
vsixMetadata=""
getMetadata() {
  vsixName=$1
  key=$2

  # check there is no error field in the metadata and retry if there is
  for j in 1 2 3 4 5; do
    vsixMetadata=$(curl -sLS "https://open-vsx.org/api/${vsixName}/${key}")
    if [[ $(echo "${vsixMetadata}" | jq -r ".error") != null ]]; then
      echo "Attempt $j/5: Error while getting metadata for ${vsixName} version ${key}"

      if [[ $j -eq 5 ]]; then
        echo "[ERROR] Maximum of 5 attempts reached - must exit!"
        exit 1
      fi
      continue
    else
      break
    fi
  done
}

versionsPage=""
getVersions() {
  vsixName=$1
  # check the versions page is empty and retry if it is
  for j in 1 2 3 4 5; do
    versionsPage=$(curl -sLS "https://open-vsx.org/api/${vsixName}/versions?size=200")
    totalSize=$(echo "${versionsPage}" | jq -r ".totalSize")
    if [[ "$totalSize" != "null" && "$totalSize" -eq 0 ]]; then
      echo "Attempt $j/5: Error while getting versions for ${vsixName}"

      if [[ $j -eq 5 ]]; then
        echo "[ERROR] Maximum of 5 attempts reached - must exit!"
        exit 1
      fi
      continue
    else
      break
    fi
  done
}
openvsxJson="../../openvsx-sync.json"
openVsxSyncFileContent=$(cat "${openvsxJson}")

numberOfExtensions=$(echo "${openVsxSyncFileContent}" | jq ". | length")
echo "The number of extensions is $numberOfExtensions"
IFS=$'\n'

for i in $(seq 0 "$((numberOfExtensions - 1))"); do
  vsixFullName=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].id")
  vsixUpdate=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].update")
  if [[ $vsixUpdate == false ]]; then
    echo -e "${BOLD}\nSkipping ${vsixFullName}${RESETSTYLE}"
    continue
  fi
  vsixVersion=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].version")
  vsixDownloadLink=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].download")
  # replace the dot by / in the vsix name
  vsixName=$(echo "${vsixFullName}" | sed 's/\./\//g')

  initMessage "Checking for a new version: $vsixFullName"

  # version should not be empty if download link was set
  if [[ $vsixDownloadLink != null ]] && [[ -z "$vsixVersion" ]]; then
    echo -e "Version should not be empty for $vsixFullName"
    exit 1
  fi

  # if download wasn't set, try to fetch from openvsx.org
  if [[ $vsixDownloadLink == null ]]; then
    # grab metadata for the vsix file
    getVersions "${vsixName}"

    # if version wasn't set in json, grab it from metadata and add it into the file
    # get all versions of the extension
    allVersions=$(echo "${versionsPage}" | jq -r '.versions')
    if [[ "$allVersions" == "{}" ]]; then
      echo "No versions found for ${vsixName}"
      exit 1
    fi
    key_value_pairs=$(echo "$allVersions" | jq -r 'to_entries[] | [ .key, .value ] | @tsv')

    # go through all versions of the extension to find the latest stable version that is compatible with the VS Code version
    resultedVersion=null
    while IFS=$'\t' read -r key value; do
      # get metadata for the version
      getMetadata "${vsixName}" "${key}"

      # check if the version is pre-release
      preRelease=$(echo "${vsixMetadata}" | jq -r '.preRelease')
      if [[ $preRelease == true ]]; then
        echo "Skipping pre-release version ${value}"
        continue
      fi

      # extract the engine version from the json metadata
      vscodeEngineVersion=$(echo "${vsixMetadata}" | jq -r '.engines.vscode')
      # remove ^ from the engine version
      vscodeEngineVersion="${vscodeEngineVersion//^/}"
      # remove >= from the engine version
      vscodeEngineVersion="${vscodeEngineVersion//>=/}"
      # replace x by 0 in the engine version
      vscodeEngineVersion="${vscodeEngineVersion//x/0}"
      # check if the extension's engine version is compatible with the code version
      # if the extension's engine version is ahead of the code version, check a next version of the extension
      if [[ "$vscodeEngineVersion" = "$(echo -e "$vscodeEngineVersion\n$codeVersion" | sort -V | head -n1)" ]]; then
        #VS Code version >= Engine version, can proceed."
        resultedVersion=$(echo "${vsixMetadata}" | jq -r ".version")
        break
      else
        echo "Skipping ${value}, it is not compatible with VS Code editor $codeVersion"
        continue
      fi
    done <<<"$key_value_pairs"

    if [[ $resultedVersion == null ]]; then
      echo "[ERROR] No stable version of $vsixFullName is compatible with VS Code editor verision $codeVersion; must exit!"
      exit 1
    else
      vsixVersion=$resultedVersion
    fi

    jq --argjson i "$i" --arg version "$vsixVersion" '.[$i] += { "version": $version }' "$openvsxJson" >tmp.json
    mv tmp.json "$openvsxJson"
  fi

done

echo -e "${GREEN}${EMOJI_PASS}${RESETSTYLE} Finished checking new versions!"
