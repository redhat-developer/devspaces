#!/bin/bash

# regenerate image tag list in LATEST_IMAGES
./product/getLatestImageTags.sh --quay --sort | tee dependencies/LATEST_IMAGES

# regenerate commit info in LATEST_IMAGES_COMMITS
rm -f dependencies/LATEST_IMAGES_COMMITS
for d in $(cat dependencies/LATEST_IMAGES); do 
  ./product/getCommitSHAForTag.sh $d | tee -a dependencies/LATEST_IMAGES_COMMITS
done

# now commit changes