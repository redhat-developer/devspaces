#!/bin/bash

# get tag(s) from a list of 1 or more images or NVRs

usage () {
	echo "
Usage: 
  $0 [image1] [image2] [image3] ... [-t show container names, sorted]
Examples: 
  $0 quay.io/devspaces/devspaces-rhel8-operator:3.0-1 registry.redhat.io/devspaces/server-rhel8:3.0 devspaces-operator-bundle-container-3.0-2
  $0 \$(cat LATEST_IMAGES) -s
"
	exit
}
if [[ $# -lt 1 ]]; then usage; fi

showContainer=0 # don't show the container, just the tag
for key in "$@"; do
  case $key in
    '-h') usage;;
    '-s') showContainer=1;;
    *) images="${images} $1";;
  esac
  shift 1
done

declare -A TAGS
for d in $images; do 
  tag=${d##*:}; tag=${tag##*-container-} # collect :tag or version after -container-
  if [[ $showContainer -eq 1 ]]; then
    c="";
    c="${d%:*}" # trim off the tag
    c="${c##*/}" # trim repo and org
    c="${c##*devspaces-3-rhel8-}" # trim devspaces-3-rhel-8 prefix
    c="${c/-rhel8/}"  # trim container midfix
    c="${c##*devspaces-}"  # trim container prefix
    c="${c%%-container-*}"  # trim container suffix
    c="${c%%-rhel8}"  # trim container suffix
  else
    (( c = c + 1 ))
  fi
  TAGS[$c]=$tag
done
# echo ${TAGS["operator"]} # or ${TAGS[3]}

if [[ $showContainer -eq 1 ]]; then # list tags + their associated container names, so we can more easily diff quay vs. nvr
  TAGS_SORTED=()
  while IFS= read -rd '' key; do
      TAGS_SORTED+=( "$key" )
  done < <(printf '%s\0' "${!TAGS[@]}" | sort -z)
  for key in "${TAGS_SORTED[@]}"; do
    printf '%s %s\n' "${TAGS[$key]}" "$key" 
  done
else # just list image tags
  for val in "${TAGS[@]}"; do
    printf '%s\n' "$val" 
  done
fi
