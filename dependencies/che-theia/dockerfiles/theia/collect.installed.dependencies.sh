#!/bin/bash

# script to collect intalled node deps into a single folder for easier tarballing

for d in \
    /opt/app-root/src/.npm-global; do \
    if [[ -d ${d} ]]; then 
        mkdir -p /tmp/root-local${d%/*}/; # one path segment less than $d
        rsync -aAXz ${d} /tmp/root-local${d%/*}/;
    else
        echo "Error: did not find directory ${d} to archive!"
        exit 1
    fi; 
done