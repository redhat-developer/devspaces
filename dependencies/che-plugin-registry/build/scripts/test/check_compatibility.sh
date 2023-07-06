#!/bin/bash
#
# Copyright (c) 2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# The script is used by openvsx-builder.Dockerfile, 
# it validates the compatibility between the engine versions of VS Code extensions (stored in .vsix archives) 
# and a Che Code version used in the current DS version. 
# It ensures that the extensions' engine versions are not ahead of the code version to avoid compatibility issues.  

trap EXIT

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-b'|'--branch') scriptBranch="$2"; shift 1;;
  esac
  shift 1
done

RED="\e[31m"
GREEN="\e[32m"
RESETSTYLE="\e[0m"
BOLD="\e[1m"
DEFAULT_EMOJI_HEADER="🏃" # could be overiden with EMOJI_HEADER="-"
EMOJI_HEADER=${EMOJI_HEADER:-$DEFAULT_EMOJI_HEADER}
DEFAULT_EMOJI_PASS="✔" # could be overriden with EMOJI_PASS="[PASS]"
EMOJI_PASS=${EMOJI_PASS:-$DEFAULT_EMOJI_PASS}
DEFAULT_EMOJI_FAIL="✘" # could be overriden with EMOJI_FAIL="[FAIL]"
EMOJI_FAIL=${EMOJI_FAIL:-$DEFAULT_EMOJI_FAIL}

function initTest() {
  echo -e "${BOLD}\n${EMOJI_HEADER} ${1}${RESETSTYLE}"
}

# Check if the information about the current branch is empty
if [[ -z "$scriptBranch" ]]; then
    echo -e "The branch is not defined. It is not possible to get Che Code version."
    echo -e "${RED}${EMOJI_FAIL}${RESETSTYLE} Test failed!"
    exit 1
fi

echo -e "${BOLD}\n${EMOJI_HEADER}${EMOJI_HEADER}${EMOJI_HEADER} Validate the compatibility between extension's engine and Che Code versions ${RESETSTYLE}"

echo "Scripts branch=${scriptBranch}"
codeVersion=$(curl -sSlko- https://raw.githubusercontent.com/redhat-developer/devspaces-images/"${scriptBranch}"/devspaces-code/code/package.json | jq -r '.version')
echo "Che Code version=${codeVersion}"

# Search for zip archives with names ending in .vsix
vsixArchives=$(find /openvsx-server/vsix -type f -name "*.vsix")

# Iterate over the vsix archives
for archive in $vsixArchives; do
  initTest "Checking $archive"
  
  # Extract the supported version of VS Code engine from the package.json
  vscodeEngineVersion=$(unzip -p "$archive" "extension/package.json" | jq -r '.engines.vscode')

  # remove ^ from the engine version
  vscodeEngineVersion="${vscodeEngineVersion//^/}"
  # remove >= from the engine version
  vscodeEngineVersion="${vscodeEngineVersion//>=/}"
  # replace x by 0 in the engine version
  vscodeEngineVersion="${vscodeEngineVersion//x/0}"
  # check if the extension's engine version is compatible with the code version
  # if the extension's engine version is ahead of the code version, check a next version of the extension
  if [[  "$vscodeEngineVersion" = "$(echo -e "$vscodeEngineVersion\n$codeVersion" | sort -V | head -n1)" ]]; then
    #VS Code version >= Engine version, can proceed."
    echo -e "${GREEN}${EMOJI_PASS}${RESETSTYLE} The engine versin is compatible in $archive!"
  else 
    echo -e "Extension's engine version is ahead of Che Code version ($codeVersion)."
    echo -e "${RED}${EMOJI_FAIL}${RESETSTYLE} Test failed!"
    exit 1
  fi
done
