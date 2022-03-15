#!/bin/bash

# script to bump .x branch to the latest version, in case Jenkins is hosed and can't do the sync jobs

usage() {
    echo "
Usage: $0 -b SOURCE_BRANCH -v CSV_VERSION
Example: $0 -b devspaces-3-rhel-8 -v 3.yy
"
    exit
}

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-b') SOURCE_BRANCH="$2"; shift 1;; # this flag will create branches instead of using branches to create tags
    '-v') CSV_VERSION="$2"; shift 1;; # 3.y.0
  esac
  shift 1
done

if [[ ! $CSV_VERSION ]]; then usage; fi
if [[ ! $SOURCE_BRANCH ]]; then usage; fi

for d in $(find -H . -maxdepth 1 -type d -a -not -name "*alt" -a -not -name "." | sort); do 
    echo "Chore: update $d/dockerfile to $CSV_VERSION in branch $SOURCE_BRANCH ... "
    cd "$d" || exit
    { 
        git checkout $SOURCE_BRANCH
        sed -i Dockerfile -r -e 's#version=".+"#version="'${CSV_VERSION}'"#g'
        git commit -s -m "chore: update dockerfile to ${CSV_VERSION}" Dockerfile
        git pull origin $SOURCE_BRANCH
        git push origin $SOURCE_BRANCH & 
    }
    cd ..
done
