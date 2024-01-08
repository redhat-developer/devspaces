#!/bin/bash -e
#
# Copyright (c) 2021-2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
# script to copy Visual Studio plugin files to staging server for Brew builds

REMOTE_USER_AND_HOST="devspaces-build@spmm-util.engineering.redhat.com"
MIDSTM_BRANCH=""
DS_VERSION=""
# optionally, delete old versions of devspaces-$DS_VERSION-pluginregistry
DELETE_OLD_VERSIONS=0 

usage ()
{
    echo "Usage: $0 -b devspaces-3.y-rhel-8 -v 3.y [-w WORKSPACE_DIR] [--delete-old-versions]
"
    exit
}

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    '-v') DS_VERSION="$2"; shift 1;; # 3.y.0
    '-w') WORKSPACE="$2"; shift 1;;
    '--delete-old-versions') DELETE_OLD_VERSIONS=1;;
  esac
  shift 1
done

if [[ ! "${MIDSTM_BRANCH}" ]]; then usage; fi
if [[ ! "${WORKSPACE}" ]]; then WORKSPACE=/tmp; fi
if [[ ! "$DS_VERSION" ]]; then DS_VERSION=$(curl -sSLo- "https://raw.githubusercontent.com/redhat-developer/devspaces/${MIDSTM_BRANCH}/dependencies/VERSION"); fi

STAGE_DIR="$WORKSPACE/devspaces-$DS_VERSION-pluginregistry"
SOURCE_DIR="$STAGE_DIR/sources"
PLUGIN_DIR="$STAGE_DIR/plugins"

mkdir -p $PLUGIN_DIR $SOURCE_DIR
mv *.vsix $PLUGIN_DIR
mv *.tar.gz $SOURCE_DIR

# next, update existing build-requirements/$PLUGIN_DIR folder (or create it if it does not exist)
rsync -rlP "$STAGE_DIR" "$REMOTE_USER_AND_HOST:staging/devspaces/build-requirements"

# optionally, delete old versions of devspaces-$DS_VERSION-pluginregistry, keeping only the last 3 folders (eg., for 3.x=3.12, keep 3.10, 3.11, and 3.12)
if [[ $DELETE_OLD_VERSIONS -eq 1 ]]; then
  OLD_VERSIONS="$(ssh "$REMOTE_USER_AND_HOST" "ls -1d staging/devspaces/build-requirements/devspaces-*-pluginregistry" 2>/dev/null | sort -V | head --lines=-3)"
  for dir in $OLD_VERSIONS; do
    echo "Remove old plugin registry folder: $dir ..."
    ssh "$REMOTE_USER_AND_HOST" "rm -fr $dir"
  done
  REMAINING_VERSIONS="$(ssh "$REMOTE_USER_AND_HOST" "ls -1d staging/devspaces/build-requirements/devspaces-*-pluginregistry" 2>/dev/null | sort -V)"
  echo "Available plugin registry folders:"
  echo "$REMAINING_VERSIONS"
fi
