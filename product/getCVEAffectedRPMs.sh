#!/bin/bash

YEAR=2021
# get pyxis data for CRW containers and compute the list of RPMs to update 
TAG="$(jq '.Version' -r dependencies/job-config.json)" 
echo "Searching for TAG=$TAG ..."

for d in $(cat dependencies/LATEST_IMAGES); do
image=${d##*/}; image=${image%%:*}; image=${image/crw-2-rhel8-/}
echo $image
curl -sSL --negotiate -u : -b ~/cookiejar.txt -c ~/cookiejar.txt  \
    "https://pyxis.engineering.redhat.com/v1/images?page_size=100&filter=brew.build~=codeready-workspaces-${image}" \
    > /tmp/crw-pyxis-${image}.json

# filter stuff from older years
jq --arg YEAR $YEAR '.data[] | select(.last_update_date|test("'$YEAR'-[0-9T+:.]+"))' /tmp/crw-pyxis-${image}.json \
    > /tmp/crw-pyxis-${image}-${YEAR}.json


# TODO only collect information if rpms and tag != null

# collect useful info - do NOT indent jq query
jq --arg TAG $TAG '.| ['\
'(.repositories[].tags[]._links.tag_history.href|select(.!=null)|select(.|test(".+osbs.+'$TAG'-[0-9]+"))|sub(".+rh-osbs/.+/tag/";"")),'\
'(.repositories[].repository|select(.|test(".+osbs.+"))), '\
'.parent_brew_build,'\
'.freshness_grades[].grade,'\
'(.repositories[].comparison.rpms.upgrade|select(.!=null)|@tsv)'\
']' \
    /tmp/crw-pyxis-${image}-${YEAR}.json \
    > /tmp/crw-pyxis-${image}-${YEAR}-collected.json

    grep -E "noarch|s390x|ppc64le|x86_64" /tmp/crw-pyxis-${image}-${YEAR}-collected.json | \
        sed -e "s#\\\t#, #g" -e "s#\"##g" > /tmp/crw-pyxis-${image}-${YEAR}-collected-rpms.txt
done

