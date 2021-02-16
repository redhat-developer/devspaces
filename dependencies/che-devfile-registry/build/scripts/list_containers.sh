#!/bin/bash
#
# Copyright (c) 2019-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# pull all external references to container images, so we can see which ones need to be airgapped/offlined

# $ ./build/scripts/list_containers.sh devfiles/

set -e

if [[ ! $1 ]]; then DIR=$(dirname "$0"); else DIR="$1"; fi

# search in devfiles folder, eg., $1 = devfiles/
echo "BEGIN list of external containers in $DIR folder:"
yq -r '.components[].image | strings' "${DIR}"/**/devfile.yaml | sort | uniq | sed "s/^/  /g"
echo "END list of external containers in $DIR folder"
