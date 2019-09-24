#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# replace all external container image references to that of an internal registry

set -e

# define which dir to process, eg., the v3/ folder
if [[ ! $1 ]]; then 
  echo "Must specify dir to change, eg., $0 v3/ myquay.mycorp.com"; exit 1
else 
  DIR="$1"
fi

# define the internal registry url to use, eg., myquay.myco.com
if [[ ! $2 ]]; then 
  echo "Must specify url of internal registry, eg., $0 $1 myquay.mycorp.com"; exit 1
else
  REPLACEMENT="$2"
fi

# optionally, define WHICH repos to replace
if [[ ! $3 ]]; then REPOS="docker.io\\|quay.io\\|registry.access.redhat.com\\|registry.redhat.io"; else REPOS="${3}"; fi

echo "Replace $REPOS with $REPLACEMENT"
metayamls="$(find "$DIR" -name "meta.yaml" | sort)"
for metayaml in ${metayamls}; do # grep "image:" $metayaml
  sed -i $metayaml -e "s#\(.\+image: \'\|\"\)\(${REPOS}\)\(.\+\)#\1${REPLACEMENT}\3#g"
done

source $(dirname "$0")/list_containers.sh $DIR "internal/external"
