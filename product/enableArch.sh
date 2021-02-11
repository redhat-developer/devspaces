#!/bin/bash -e
#
# Copyright (c) 2020-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
# Utility script to uncomment a previously commented-out arch in a container.yaml file
# This script has questionable usefulness, so YMMV. Might delete it some day. ~nboldt

DWNSTM_BRANCH="crw-2.8-rhel-8"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-b') DWNSTM_BRANCH="$2"; shift 1;;
    *) ARCH="$1"
  esac
  shift 1
done

usage()
{
    echo "
Usage: $0 [-b crw-branch] [arch-to-enable]
Example: $0 -b ${DWNSTM_BRANCH} ppc64le"
}
if [[ ! $ARCH ]]; then usage; exit; fi

for d in . */; do 
    if [[ -f $d/container.yaml ]]; then 
        echo; if [[ $d == "." ]]; then echo "== $(basename $(pwd)) =="; else echo "== $d =="; fi
        cd $d
            grep -E " - ${ARCH}" -r || true
            if [[ $(grep -E "^ *# *- ${ARCH}" -r) ]]; then
                git fetch
                git checkout $DWNSTRM_BRANCH || true
                git pull origin $DWNSTRM_BRANCH || true
                sed -i container.yaml -r -e "s| *# *- ${ARCH}|  - ${ARCH}|" || true
                git commit -s -m "Enable ${ARCH} builds in container.yaml" container.yaml || true
                git push origin $DWNSTRM_BRANCH || true
            fi
        cd ..
    fi
done
