#!/bin/bash

trap EXIT

set -e
set -o pipefail

downloadVsix=1
openvsxJson="/openvsx-server/openvsx-sync.json"

usage()
{
    echo "Usage: $0 -b devspaces-3.y-rhel-8 -j /path/to/openvsx-sync.json --no-download

All arguments are optional.

-b|--branch     Specify a devspaces branch. Otherwise will be computed from local git directory
-j|--json       Specify a path for openvsx-sync.json. Default: /openvsx-server/openvsx-sync.json
--no-download   Do not download vsix files, only update versions in the openvsx-sync.json"
    exit
}

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-b'|'--branch') scriptBranch="$2"; shift 1;;
    '-j'|'--json') openvsxJson="$2"; shift 1;;
    '--no-download') downloadVsix=0;;
    '-h'|'--help') usage;;
  esac
  shift 1
done

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
  echo -n -e "${BOLD}\n${EMOJI_HEADER} ${1}${RESETSTYLE} ... "
}

echo "Scripts branch=${scriptBranch}"
codeVersion=$(curl -sSlko- https://raw.githubusercontent.com/redhat-developer/devspaces-images/"${scriptBranch}"/devspaces-code/code/package.json | jq -r '.version')
echo "Che Code version=${codeVersion}"

# Check if the information about the current branch is empty
if [[ -z "$scriptBranch" ]]; then
    echo -e "The branch is not defined. It is not possible to get Che Code version."
    echo -e "${RED}${EMOJI_FAIL}${RESETSTYLE} Test failed!"
    exit 1
fi

# pull vsix from OpenVSX
mkdir -p /tmp/vsix
openVsxSyncFileContent=$(cat "$openvsxJson")
numberOfExtensions=$(echo "${openVsxSyncFileContent}" | jq ". | length")
IFS=$'\n' 

for i in $(seq 0 "$((numberOfExtensions - 1))"); do
    vsixFullName=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].id")
    vsixVersion=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].version")
    vsixDownloadLink=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].download")

    # extract from the vsix name the publisher name which is the first part of the vsix name before dot
    vsixPublisher=$(echo "${vsixFullName}" | cut -d '.' -f 1)

    # replace the dot by / in the vsix name
    vsixName=$(echo "${vsixFullName}" | sed 's/\./\//g')

    # if download wasn't set, try to fetch from openvsx.org
    if [[ $vsixDownloadLink == null ]]; then
        # grab metadata for the vsix file
        # if version wasn't set, use latest
        if [[ $vsixVersion == null ]]; then
            vsixMetadata=$(curl -sLS "https://open-vsx.org/api/${vsixName}/latest")
            # if version wasn't set in json, grab it from metadata and add it into the file
            # get all versions of the extension
            allVersions=$(echo "${vsixMetadata}" | jq -r '.allVersions')
            key_value_pairs=$(echo "$allVersions" | jq -r 'to_entries[] | [ .key, .value ] | @tsv')
            
            # go through all versions of the extension to find the latest stable version that is compatible with the VS Code version
            resultedVersion=null
            while IFS=$'\t' read -r key value; do
                # get metadata for the version
                vsixMetadata=$(curl -sLS "https://open-vsx.org/api/${vsixName}/${key}")
                # check there is no error field in the metadata
                if [[ $(echo "${vsixMetadata}" | jq -r ".error") != null ]]; then
                    echo "Error while getting metadata for ${vsixFullName} version ${key}"
                    continue
                fi
      
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
                if [[  "$vscodeEngineVersion" = "$(echo -e "$vscodeEngineVersion\n$codeVersion" | sort -V | head -n1)" ]]; then
                    #VS Code version >= Engine version, can proceed."
                    resultedVersion=$(echo "${vsixMetadata}" | jq -r ".version")
                    break
                else 
                    echo "Skipping ${value}, it is not compatible with VS Code editor $codeVersion"
                    continue
                fi
            done <<< "$key_value_pairs"

            if [[ $resultedVersion == null ]]; then
                echo "[ERROR] No stable version of $vsixFullName is compatible with VS Code editor verision $codeVersion; must exit!"
                exit 1
            else
                vsixVersion=$resultedVersion
            fi

            jq --argjson i "$i" --arg version "$vsixVersion" '.[$i] += { "version": $version }' "$openvsxJson" > tmp.json
            mv tmp.json "$openvsxJson"
        else
            vsixMetadata=$(curl -sLS "https://open-vsx.org/api/${vsixName}/${vsixVersion}")
        fi 
        
        # check there is no error field in the metadata
        if [[ $(echo "${vsixMetadata}" | jq -r ".error") != null ]]; then
            echo "Error while getting metadata for ${vsixFullName}"
            echo "${vsixMetadata}"
            exit 1
        fi
        
        # extract the download link from the json metadata
        vsixDownloadLink=$(echo "${vsixMetadata}" | jq -r '.files.download')
        # get universal download link
        vsixUniversalDownloadLink=$(echo "${vsixMetadata}" | jq -r '.downloads."universal"')
        if [[ $vsixUniversalDownloadLink != null ]]; then
            vsixDownloadLink=$vsixUniversalDownloadLink
        else
            # get linux download link
            vsixLinuxDownloadLink=$(echo "${vsixMetadata}" | jq -r '.downloads."linux-x64"')
            if [[ $vsixLinuxDownloadLink != null ]]; then
                vsixDownloadLink=$vsixLinuxDownloadLink
            fi
        fi
    fi

    if [[ $downloadVsix = 1 ]]; then
        echo "Downloading ${vsixDownloadLink} into ${vsixPublisher} folder..."
        vsixFilename="/tmp/vsix/${vsixFullName}-${vsixVersion}.vsix"
        # download the latest vsix file in the publisher directory
        curl -sLS "${vsixDownloadLink}" -o "${vsixFilename}"

        initTest "Checking $vsixFilename"
  
        # Extract the supported version of VS Code engine from the package.json
        vscodeEngineVersion=$(unzip -p "$vsixFilename" "extension/package.json" | jq -r '.engines.vscode')

        # remove ^ from the engine version
        vscodeEngineVersion="${vscodeEngineVersion//^/}"
        # remove >= from the engine version
        vscodeEngineVersion="${vscodeEngineVersion//>=/}"
        # replace x by 0 in the engine version
        vscodeEngineVersion="${vscodeEngineVersion//x/0}"
        # check if the extension's engine version is compatible with the code version
        # if the extension's engine version is ahead of the code version, check a next version of the extension
        if [[  "$vscodeEngineVersion" = "$(echo -e "$vscodeEngineVersion\n$codeVersion" | sort -V | head -n1)" ]]; then
            #VS Code version >= Engine version, can proceed."
            echo -e "${GREEN}${EMOJI_PASS}${RESETSTYLE} compatible."
        else 
            echo -e "Extension requires a newer engine version than Che Code version ($codeVersion)."
            echo -e "${RED}${EMOJI_FAIL}${RESETSTYLE} Test failed!"
            exit 1
        fi
    fi
done;
