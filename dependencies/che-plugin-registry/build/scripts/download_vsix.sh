#!/bin/bash

set -e
set -o pipefail

# pull vsix from OpenVSX
mkdir -p /tmp/vsix
openVsxSyncFileContent=$(cat "/openvsx-server/openvsx-sync.json")
listOfVsixes=$(echo "${openVsxSyncFileContent}" | jq -r ".[]")
IFS=$'\n' 

for vsixFullName in $listOfVsixes; do
    # extract from the vsix name the publisher name which is the first part of the vsix name before dot
    vsixPublisher=$(echo "${vsixFullName}" | cut -d '.' -f 1)

    # replace the dot by / in the vsix name
    vsixName=$(echo "${vsixFullName}" | sed 's/\./\//g')

    # grab metadata for the vsix file
    vsixMetadata=$(curl -sL "https://open-vsx.org/api/${vsixName}/latest")

    # check there is no error field in the metadata
    if [[ $(echo "${vsixMetadata}" | jq -r ".error") != null ]]; then
        echo "Error while getting metadata for ${vsixFullName}"
        echo "${vsixMetadata}"
        exit 1
    fi

    # grab the version field from metadata
    vsixVersion=$(echo "${vsixMetadata}" | jq -r '.version')

    # extract the download link from the json metadata
    vsixDownloadLink=$(echo "${vsixMetadata}" | jq -r '.files.download')

    echo "Downloading ${vsixDownloadLink} into ${vsixPublisher} folder..."
    vsixFilename="/tmp/vsix/${vsixFullName}-${vsixVersion}.vsix"
    # download the latest vsix file in the publisher directory
    curl -sL "${vsixDownloadLink}" -o "${vsixFilename}"

    sed -i "s/$vsixFullName/$vsixFullName:$vsixVersion/g" /openvsx-server/openvsx-sync.json
done;
