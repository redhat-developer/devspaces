#!/bin/bash

set -e
set -o pipefail

/usr/local/bin/start_services.sh

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
openVsxSyncFileContent=$(cat "/openvsx-server/openvsx-sync.json")
numberOfExtensions=$(echo "${openVsxSyncFileContent}" | jq ". | length")
listOfPublishers=()
IFS=$'\n' 

for i in $(seq 0 "$((numberOfExtensions - 1))"); do
    vsixFullName=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].id")
    vsixVersion=$(echo "${openVsxSyncFileContent}" | jq -r ".[$i].version")
    # extract from the vsix name the publisher name which is the first part of the vsix name before dot
    vsixPublisher=$(echo "${vsixFullName}" | cut -d '.' -f 1)

    vsixFilename="/openvsx-server/vsix/${vsixFullName}-${vsixVersion}.vsix"

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
