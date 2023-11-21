#!/bin/bash
#
# Copyright (c) 2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
# update a container.yaml to pull in latest SHA references for specified tags/branches

# NOTE: if container.yaml has cachito reference(s) to repos other than Che or Dev Spaces, eg.,
#     repo: https://github.com/golang/tools
#     ref: fd02dfae644ce04dfd4bb3828cf576b9d8717f79
# Must hardcoded a value in job-config.json, mapping to the .remote_source's .name in container.yaml (eg., gopls)
# ==> https://github.com/redhat-developer/devspaces/blob/devspaces-3-rhel-8/dependencies/job-config.json#L553 (look for gopls)

set -e

usage () {
    echo "
Usage:

  $0 -b MIDSTM_BRANCH /path/to/container.yaml

Options:

  -h, --help              show this help

Example:

  $0 -b devspaces-3-rhel-8 /tmp/container.yaml
"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    *) yamls="${yamls} $1";;
  esac
  shift 1
done

if [[ ! $MIDSTM_BRANCH ]] || [[ ! $yamls ]]; then usage; exit 1; fi

if [[ $MIDSTM_BRANCH == "devspaces-3-rhel-8" ]]; then
  JOB_BRANCH=3.x
else 
  JOB_BRANCH=${MIDSTM_BRANCH%-rhel-*};JOB_BRANCH=${JOB_BRANCH#devspaces-}
fi

# shellcheck disable=SC2143,SC2086
for yaml in $yamls; do 
  if [[ $(grep 'remote_sources:' ${yaml}) ]]; then
      # clean out old comments in container.yaml
      sed -i '/# must be full 40 char sha, matching regex/d' $yaml

      for repo in $(yq -r '.remote_sources[].remote_source.repo' $yaml); do
          branchOrTag=""
          SHA=""

          # CASE 1: cachito sources where we hardcode a branch or tag in job-config.json (gopls, xdebug)
          name=$(cat ${yaml} | yq -r '.remote_sources[]|select(.remote_source.repo=="'$repo'")' | yq -r ".name")

          JCJ=/tmp/job-config.json
          curl -sSLo ${JCJ} https://raw.githubusercontent.com/redhat-developer/devspaces/devspaces-3-rhel-8/dependencies/job-config.json
          # check if there's an entry (both a key and a version) for this remote source in JCJ
          branchOrTag="$(jq -r --arg name "$name" --arg ver "$JOB_BRANCH" '.Other[$name][$ver]' $JCJ)"

          # CASE 2: cachito sources of devspaces-images, devspaces-samples or che repos, where we know which branch to use
          if [[ "${branchOrTag}" == "null" ]]; then # not found above
            # if devspaces-samples, use MIDSTM_BRANCH
            if [[ $(echo $repo | grep 'devspaces-images') ]] || [[ $(echo $repo | grep 'devspaces-samples') ]]; then
                branchOrTag="${MIDSTM_BRANCH}"
            elif [[ $(echo $repo | grep 'eclipse-che') ]] || [[ $(echo $repo | grep 'che-incubator') ]]; then
                # if che repo, use upstream_branch, starting from latest and falling back to previous (7.64.x -> 7.63.x)
                for n in 0 1; do
                branchOrTag="$(jq -r --arg ver "$JOB_BRANCH" --arg n $n '.Jobs["operator"][$ver].upstream_branch['$n']' $JCJ)"
                # echo "Check $branchOrTag (index $n) ... "
                SHA=$(git ls-remote $repo refs/heads/$branchOrTag | sed -r -e "s@(.+)\\t.+@\\1@g")
                if [[ $SHA ]]; then break; fi
                done
                # echo "Got $SHA for index $n = $branchOrTag"
            fi
          fi

          # Try branch (/heads/)
          if [[ ! $SHA ]]; then
            SHA=$(git ls-remote $repo refs/heads/$branchOrTag | sed -r -e "s@(.+)\\t.+@\\1@g")
          fi
          # Use tag (/tags/) if branch does not exist
          if [[ ! $SHA ]]; then
            SHA=$(git ls-remote $repo refs/tags/$branchOrTag | sed -r -e "s@(.+)\\t.+@\\1@g")
          fi
          # Or if there's a SHA in job-config.json, use that directly
          if [[ ! $SHA ]]; then
            SHA="$branchOrTag"
          fi
          # sed replacement (match a line, move *N*ext line and *S*ubstitute it) will only work for this 2-line pattern:
          #   repo: https://github.com/redhat-developer/devspaces-images.git
          #    ref: e8b28394b00f6d320ec7a9b758875c674595ed58
          sed -r -i -e "/.+repo: .+${repo##*/}.*/{n;s/ref: .*/ref: $SHA/}" $yaml
      done
  else
    echo "No 'remote_sources:' found in $yaml, nothing to do!"
  fi
done
