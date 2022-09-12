#!/bin/bash

set -e
set -o pipefail

/start-services.sh

# install temporary nodejs
mkdir -p /tmp/opt/nodejs && curl -sL https://nodejs.org/download/release/v14.18.3/node-v14.18.3-linux-x64.tar.gz | tar xzf - -C /tmp/opt/nodejs --strip-components=1
# add path
export PATH=/tmp/opt/nodejs/bin:$PATH
export npm_config_cache=/tmp/otp/cache

# install the cli
npm install -g ovsx@0.5.0

# insert user
psql -c "INSERT INTO user_data (id, login_name) VALUES (1001, 'eclipse-che');"
psql -c "INSERT INTO personal_access_token (id, user_data, value, active, created_timestamp, accessed_timestamp, description) VALUES (1001, 1001, 'eclipse_che_token', true, current_timestamp, current_timestamp, 'extensions');"
psql -c "UPDATE user_data SET role='admin' WHERE user_data.login_name='eclipse-che';"


echo "Starting to publish extensions...."
export OVSX_REGISTRY_URL=http://localhost:9000
export OVSX_PAT=eclipse_che_token

containsElement () { for e in "${@:2}"; do [[ "$e" = "$1" ]] && return 0; done; return 1; }


# pull vsix from OpenVSX
mkdir -p /tmp/vsix
openVsxSyncFileContent=$(cat "/openvsx-sync.json")
listOfVsixes=$(echo "${openVsxSyncFileContent}" | jq -r ".[]")
listOfPublishers=()
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

    # check if publisher is in the list of publishers
    if ! containsElement "${vsixPublisher}" "${listOfPublishers[@]}"; then
        listOfPublishers+=("${vsixPublisher}")
        # create namespace
        ovsx create-namespace "${vsixPublisher}"
    fi

    # publish the file
    ovsx publish "${vsixFilename}"

    # remove the downloaded file
    rm "${vsixFilename}"

done;


# disable the personal access token
psql -c "UPDATE personal_access_token SET active = false;"

# cleanup
rm -rf /tmp/opt/nodejs
rm -rf /tmp/extension_*.vsix
rm -rf /tmp/vsix
rm -rf /tmp/otp/cache
