#!/bin/bash

set -e
set -o pipefail

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
            vsixVersion=$(echo "${vsixMetadata}" | jq -r '.version')
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
