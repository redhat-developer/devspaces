#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

# search for yaml files with filename extension containing arch running on.
# if they exist, replace.  if any devfile has size 0, remove it and corresponding
# yaml files from that directory.

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
YAML_ROOT="$1"

# for testing, support passing in uname as a 2nd param, eg., s390x or ppc64le
if [[ $2 ]]; then arch="$2"; else arch="$(uname -m)"; fi

yamlfiles=$("$SCRIPT_DIR"/list_yaml.sh "$YAML_ROOT")

# shellcheck disable=SC2086
for yamlfile in $yamlfiles ; do
  if [[ -e ${yamlfile}.${arch} ]] ; then
      mv ${yamlfile} ${yamlfile}.orig
      mv ${yamlfile}.${arch} ${yamlfile}
      echo "[INFO] swapped to $arch version of ${yamlfile}.${arch}"
  fi

  # remove empty
  if [[ ! -s ${yamlfile} ]] ; then
    mv ${yamlfile} ${yamlfile}.removed
    if [[ -e "$(dirname $yamlfile)/meta.yaml" ]] ; then
      mv "$(dirname $yamlfile)/meta.yaml" "$(dirname $yamlfile)/meta.yaml.removed"
    fi
    echo "[INFO] removed empty yamlfile ${yamlfile}"
  fi
done
