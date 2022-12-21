#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Utility script to approve and merge a PR by URL
#

command -v gh >/dev/null 2>&1     || which gh >/dev/null 2>&1     || { echo "gh is not installed - must install from https://cli.github.com/"; usage; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [URL1] [URL2 ...] [OPTIONS]

Options:
  -a                    : approve PR
  -m                    : squash-merge PR
  -v                    : verbose output
  -h, --help            : show this help

Example:
  $0 -a -m https://github.com/eclipse-che/che-devfile-registry/pull/697/files
EOF
}

DO_APPROVE=0
DO_MERGE=0
VERBOSE=0

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-a'|'--approve') DO_APPROVE=1;;
    '-m'|'--merge') DO_MERGE=1;;
    '-v'|'--verbose') VERBOSE=1;;
    '-h'|'--help') usage;;
    *) URLs="$URLs $1";;
  esac
  shift 1
done

for URL in $URLs; do
    R=$URL; R=${R%/pull/*}; # echo $R
    PR=$URL; PR=${PR##*/pull/}; PR=${PR%%/*}; # echo $PR

    if [[ $DO_APPROVE -eq 1 ]]; then
        approve_cmd="gh pr review $PR --approve -R $R"
        if [[ VERBOSE -eq 1 ]]; then
            echo "To approve: 
  $approve_cmd"
        fi
        $approve_cmd
    fi

    if [[ $DO_MERGE -eq 1 ]]; then
        merge_cmd="gh pr merge $PR -s -R $R"
        if [[ VERBOSE -eq 1 ]]; then
            echo "To merge:
  $merge_cmd"
        fi
        $merge_cmd
    fi
done