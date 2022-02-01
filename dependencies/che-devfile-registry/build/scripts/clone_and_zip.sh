#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

set -e

TEMP_REPO=$(mktemp -d -u)

# Clone a git repository and create an archive zip at a specified location
# Args:
#   $1 - URL of git repo
#   $2 - branch to archive
#   $3 - destination path for the archived project zip file
#   $4 - sparse checkout directory
function clone_and_zip() {
  local repo="$1"
  local branch="$2"
  local destination="$3"
  local sparse_checkout_dir="$4"

  git clone "$repo" -b "$branch" --depth 1 "$TEMP_REPO" -q
  pushd "$TEMP_REPO" &>/dev/null
    if [ -n "$sparse_checkout_dir" ]; then
      echo "    Using sparse checkout dir '$sparse_checkout_dir'"
      git archive -9 "$branch" "$sparse_checkout_dir" -o "$destination"
    else
      git archive -9 "$branch" -o "$destination"
    fi
  popd &>/dev/null
  rm -rf "$TEMP_REPO"
}
