#!/bin/bash

# simple utility script to delete tags from the DS images, eg., to purge obsolete nightly tags

# get ACCESS_TOKEN from https://quay.io/organization/devspaces/application/ZLH33ADU8A8PHC6N9UNM

# Thanks to https://gist.github.com/berendt/fca9bfae23d6462ffab6e861dee82707#file-delete-a-tag-on-all-repositories-in-an-organisation for inspiration!

NAMESPACE=devspaces
TAG=nightly
# delete all tags in DS images
for d in $(cat ../dependencies/LATEST_IMAGES); do
    image=${d%:*}:${TAG}
    repo=${d%:*}; repo=${repo##*/}
    echo $image;
    tagdate=$(sid $image 2>/dev/null|jq '.Labels["build-date"]')
    if [[ $tagdate ]]; then
        echo "Delete tag $TAG ($tagdate) from $repo..."
        curl -s -X DELETE -H "Authorization: Bearer $ACCESS_TOKEN" https://quay.io/api/v1/repository/$NAMESPACE/$repo/tag/$TAG
        echo
    fi
done
