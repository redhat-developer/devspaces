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

yamlfiles=$($SCRIPT_DIR/list_yaml.sh "$YAML_ROOT")

for yamlfile in $yamlfiles ; do
  arch="$(uname -m)"
  if [[ -e ${yamlfile}.${arch} ]] ; then
      echo "[INFO] swapped to $arch version of ${yamlfile}.${arch}"
      mv ${yamlfile} ${yamlfile}.orig
      mv ${yamlfile}.${arch} ${yamlfile}
  fi

  # remove empty
  if [[ ! -s ${yamlfile} ]] ; then
    echo "[INFO] removing empty yamlfile ${yamlfile}"
    mv ${yamlfile} ${yamlfile}.removed
    if [[ -e "$(dirname $yamlfile)/meta.yaml" ]] ; then
      mv "$(dirname $yamlfile)/meta.yaml" "$(dirname $yamlfile)/meta.yaml.removed"
    fi
  fi
done
