#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# pull all external references to container images

set -e

if [[ ! $1 ]]; then DIR=$(dirname "$0"); else DIR="$1"; fi
if [[ ! $2 ]]; then LABEL="external"; else LABEL="$2"; fi

declare -A images

# search in a plugin folder, eg., $1 = v3/
echo "BEGIN list of ${LABEL} containers in $DIR folder:"
metayamls="$(find "$DIR" -name "meta.yaml" | sort)"
c=0; for metayaml in ${metayamls}; do let c=c+1; done
i=0; for metayaml in ${metayamls}; do
  let i=i+1
  # echo "[$i/$c] Fetch from '${metayaml%/meta.yaml}'"
  # get files into local repo
  for image in $(cat $metayaml | egrep ".+image:" | sed -e "s#.\+image:##g" | tr -d "\""); do
    # echo "Got $image"
    [[ ! -n "${images['$image']}" ]] && images[$image]="$image"
  done
done

sorted_images=(); while read -d $'\0' elem; do sorted_images[${#sorted_images[@]}]=$elem; done < <(printf '%s\0' "${images[@]}" | sort -z);

for image in "${sorted_images[@]}"; do 
    echo "  $image"
done
echo "END list of ${LABEL} containers in $DIR folder"
