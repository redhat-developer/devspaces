#!/bin/bash

# get tag(s) from a list of 1 or more images or NVRs

usage () {
	echo "
Usage: 
  $0 [image1] [image2] [image3] ...
Example: 
  $0 quay.io/crw/crw-2-rhel8-operator-metadata:2.3-54 registry.redhat.io/codeready-workspaces/server-rhel8:2.2 codeready-workspaces-rhel8-operator-metadata-container-2.3-54
"
	exit
}
if [[ $# -lt 1 ]]; then usage; fi

for key in "$@"; do
  case $key in
    '-h') usage;;
    *) images="${images} $1";;
  esac
  shift 1
done

for d in $images; do tag=${d##*:}; tag=${tag##*-container-}; echo $tag; done
