#!/bin/bash

set -e
set -o pipefail

scriptsBranch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ $scriptsBranch != "devspaces-3."*"-rhel-8" ]]; then
    scriptsBranch="devspaces-3-rhel-8"
fi
codeVersion=$(curl -sSlko- https://raw.githubusercontent.com/redhat-developer/devspaces-images/"${scriptsBranch}"/devspaces-code/code/package.json | jq -r '.version')
echo "Che Code version=${codeVersion}"

# pull vsix from OpenVSX
mkdir -p /tmp/vsix
openVsxSyncFileContent=$(cat "/openvsx-server/openvsx-sync.json")
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

            jq --argjson i "$i" --arg version "$vsixVersion" '.[$i] += { "version": $version }' /openvsx-server/openvsx-sync.json > tmp.json
            mv tmp.json /openvsx-server/openvsx-sync.json
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
        fi
    fi

    echo "Downloading ${vsixDownloadLink} into ${vsixPublisher} folder..."
    vsixFilename="/tmp/vsix/${vsixFullName}-${vsixVersion}.vsix"
    # download the latest vsix file in the publisher directory
    curl -sLS "${vsixDownloadLink}" -o "${vsixFilename}"
done;
