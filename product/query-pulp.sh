#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Utility script to query pulp repos for content_sets that can be used in OSBS builds.
# Query is matched via regex on repo display names.
#

set -e

usage() {
  cat <<EOF
query-pulp.sh queries Red Hat pulp repos (https://rhsm-pulp.corp.redhat.com/) for packages in order to find
content_sets that can be used in OSBS builds. QUERY is used to filter repository display names via regex. By
default, this script prints JSON objects containing the display name, content set, and url to the repo. Note
that results may include empty repos; the repo_url should be checked to verify the desired package is present.

Usage: $0 [OPTIONS] QUERY

Options:
  -d, --displayname : print only the display name for matching repos
  -f, --full        : print full response for matching repos
  -m, --more        : print more information about repos
  -h, --help        : display this help text

Example:
  $0 'ocp-tools.*rhel-8.*x86_64'
EOF
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-d'|'--displayname') DISPLAY_NAME_ONLY="true";;
    '-f'|'--full') FULL="true";;
    '-m'|'--more') MORE="true";;
    '-h'|'--help') usage; exit 0;;
    -*|--*) echo -e "[ERROR] Unknown option: $1.\n"; usage; exit 1;;
    *) if [ -z "$QUERY" ]; then QUERY=$1; else echo -e "[ERROR] Only one positional argument allowed.\n"; usage; exit 1; fi;;
  esac
  shift 1
done

if [ -z "$QUERY" ]; then
  echo -e "[ERROR] A query is required.\n"
  usage
  exit 1
fi

if [ "$FULL" == "true" ]; then
  curl -s -k --user qa:qa  https://rhsm-pulp.corp.redhat.com/pulp/api/v2/repositories/search/ \
    --data '{"criteria": {"filters": {"display_name": {"$regex": "'"$QUERY"'"}}}}' \
    | jq '.'
elif [ "$DISPLAY_NAME_ONLY" == "true" ]; then
  curl -s -k --user qa:qa  https://rhsm-pulp.corp.redhat.com/pulp/api/v2/repositories/search/ \
    --data '{"criteria": {"filters": {"display_name": {"$regex": "'"$QUERY"'"}}}}' \
    | jq -r '.[].display_name'
elif [ "$MORE" == "true" ]; then
  curl -s -k --user qa:qa  https://rhsm-pulp.corp.redhat.com/pulp/api/v2/repositories/search/ \
    --data '{"criteria": {"filters": {"display_name": {"$regex": "'"$QUERY"'"}}}}' \
    | jq '.[] | {display_name, "content_set": .notes.content_set, "repo_url": "https://rhsm-pulp.corp.redhat.com/\(.notes.relative_url)", "include_in_download_service": .notes.include_in_download_service}'
else
  curl -s -k --user qa:qa  https://rhsm-pulp.corp.redhat.com/pulp/api/v2/repositories/search/ \
    --data '{"criteria": {"filters": {"display_name": {"$regex": "'"$QUERY"'"}}}}' \
    | jq -c '.[] | {display_name, "content_set": .notes.content_set, "repo_url": "https://rhsm-pulp.corp.redhat.com/\(.notes.relative_url)"}'
fi
