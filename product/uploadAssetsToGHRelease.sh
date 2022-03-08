#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
# push locally built asset* files to github

set -e

TARGETDIR=$(pwd)

# defaults
GITHUB_REPO_DEFAULT="redhat-developer/codeready-workspaces-images" # or redhat-developer/codeready-workspaces-chectl
CSV_VERSION="2.y.0" # csv 2.y.0
ASSET_NAME=""
fileList=""
DELETE_ASSETS=0 # this also deletes the release in which the assets are stored
PUBLISH_ASSETS=0 # publish asset(s) to GH
PULL_ASSETS=0 # pull asset(s) from GH
PRE_RELEASE="--prerelease" # by default create pre-releases
MIDSTM_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "crw-2-rhel-8")
if [[ ${MIDSTM_BRANCH} != "crw-"*"-rhel-"* ]]; then MIDSTM_BRANCH="crw-2-rhel-8"; fi

usageGHT() {
    echo 'Setup:

First, export your GITHUB_TOKEN:

  export GITHUB_TOKEN="...github-token..."
'
  usage
}
usage () {
    echo "
Usage:

  $0 -v CRW_CSV_VERSION -n ASSET_NAME file1.tar.gz [file2.tar.gz ...]

Options:

  -d, --delete-assets     delete release + asset file(s) defined by CSV_VERSION and ASSET_NAME; 
                            used to prepare for creating a new release with fresh timestamp + assets

  -a, --publish-assets    publish asset file(s) to release defined by CSV_VERSION and ASSET_NAME
    -b branch             branch from which to create tag + release; defaults to $MIDSTM_BRANCH
    --release             by default, do a pre-release; use this flag to create a full release (for GA only)

  -p, --pull-assets       fetch asset file(s) from release defined by CSV_VERSION and ASSET_NAME
    --repo-path /path/gh  if already checked out, specify which GH folder to use to pull for release files
    --repo org/reponame   if not checked out, specify from which GH repo to find the release files; 
                            default: $GITHUB_REPO_DEFAULT (unless run from within a GH repo folder)
    --target   /some/dir  after using the GH repo to fetch assets, copy them to this specified folder; 
                            default: $TARGETDIR

  -h, --help              show this help

Examples:

  $0 --delete-assets -v 2.y.0 -n traefik              # delete release, tag, and asset(s)
  $0 --publish-assets -v 2.y.0 -n traefik asset-*gz   # publish specific asset(s)
  $0 --pull-assets -v 2.y.0 -n traefik asset-*gz      # pull specific asset(s)
  $0 --pull-assets -v 2.y.0 -n traefik                # pull all assets
"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-v') CSV_VERSION="$2"; shift 1;;
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    '-ght') GITHUB_TOKEN="$2"; export GITHUB_TOKEN="${GITHUB_TOKEN}"; shift 1;;
    '-n'|'--asset-name')       ASSET_NAME="$2"; shift 1;;

    '-d'|'--delete-assets')    DELETE_ASSETS=1;;
    '-a'|'--publish-assets')   PUBLISH_ASSETS=1;;
    '-p'|'--pull-assets')      PULL_ASSETS=1;;
    '--repo')                  PULL_ASSETS=1; GITHUB_REPO="$2"; shift 1;;      # if not checked out, specify from which GH repo to find the release files
    '--repo-path')             PULL_ASSETS=1; GITHUB_REPO_PATH="$2"; shift 1;; # if checked out, specify which GH folder to use to pull release files
    '--target')                PULL_ASSETS=1; TARGETDIR="$2"; shift 1;;

    '--prerelease')            PRE_RELEASE="$1";; # --prerelease
    '--release')               PRE_RELEASE="";;   # not a prerelease
    '-h'|'--help') usageGHT; exit 0;;
    *) fileList="${fileList} $1";;
  esac
  shift 1
done

if [[ ! "${GITHUB_TOKEN}" ]]; then usageGHT; exit 1; fi
if [[ $CSV_VERSION == "2.y.0" ]]; then echo "Error: must specify CSV_VERSION with -v flag.";echo; usage; exit 1; fi
if [[ $ASSET_NAME == "" ]]; then echo "Error: must specify ASSET_NAME with -n flag.";echo; usage; exit 1; fi
if [[ $DELETE_ASSETS -eq 0 ]] && [[ $PUBLISH_ASSETS -eq 0 ]] && [[ $PULL_ASSETS -eq 0 ]]; then 
  echo "Error: Must specify which operation to run:
  --delete-assets
  --publish-assets
  --pull-assets"; echo; usage; exit 1
fi

export GITHUB_TOKEN=${GITHUB_TOKEN}

# this also deletes the release in which the assets are stored
if [[ $DELETE_ASSETS -eq 1 ]]; then
  #check if release exists
  if [[ $(hub release | grep ${CSV_VERSION}-${ASSET_NAME}-assets) ]]; then
    echo "Delete release ${CSV_VERSION}-${ASSET_NAME}-assets"
    hub release delete "${CSV_VERSION}-${ASSET_NAME}-assets"
    hub push origin :"${CSV_VERSION}-${ASSET_NAME}-assets"
  else
    echo "No release with tag ${CSV_VERSION}-${ASSET_NAME}-assets"
  fi
fi

if [[ $PUBLISH_ASSETS -eq 1 ]]; then
  if [[ -z $fileList ]]; then echo "Error: no files specified to publish!"; usage; exit 1; fi
  # check if release exists
  if [[ ! $(hub release | grep ${CSV_VERSION}-${ASSET_NAME}-assets) ]]; then
    #no existing release, create it
    hub release create -t "${MIDSTM_BRANCH}" \
      -m "Assets for the ${CSV_VERSION} ${ASSET_NAME} release" -m "Container build asset files for ${CSV_VERSION}" \
      ${PRE_RELEASE} "${CSV_VERSION}-${ASSET_NAME}-assets"
  fi

  # upload artifacts for each platform 
  for fileToPush in $fileList; do
    # attempt to upload a new file
    echo "Upload new asset $fileToPush"
    hub release edit -a ${fileToPush} "${CSV_VERSION}-${ASSET_NAME}-assets" \
      -m "Assets for the ${CSV_VERSION} ${ASSET_NAME} release" -m "Container build asset files for ${CSV_VERSION}"
  done
fi

if [[ $PULL_ASSETS -eq 1 ]]; then
  TMP=$(mktemp -d)
  if [[ -d $GITHUB_REPO_PATH ]]; then # use the specified GH checkout folder
    pushd $GITHUB_REPO_PATH >/dev/null
    if [[ $(git rev-parse --abbrev-ref HEAD 2>&1 | grep "not a git repo") ]] || [[ ! $(git remote -v 2>&1 | grep github) ]]; then
      echo "Error: $GITHUB_REPO_PATH is not inside a github checkout folder!"
      echo "Error: use --repo, --repo-path, and/or --target flags."
      usage; exit 1
    fi
  # if not a github checkout folder
  elif [[ $(git rev-parse --abbrev-ref HEAD 2>&1 | grep "not a git repo") ]] || [[ ! $(git remote -v 2>&1 | grep github) ]] || [[ $GITHUB_REPO ]]; then
    if [[ ! -d $GITHUB_REPO_PATH ]]; then # clone the specified GH repo and use that to fetch assets
      pushd $TMP >/dev/null
      if [[ $GITHUB_REPO ]]; then
        git clone --depth 1 https://github.com/$GITHUB_REPO --branch crw-2-rhel-8 --single-branch sources
      else 
        git clone --depth 1 https://github.com/$GITHUB_REPO_DEFAULT --branch crw-2-rhel-8 --single-branch sources
      fi
      cd sources
    else
      echo "Error: $TARGETDIR is not inside a github checkout folder!"
      echo "Error: use --repo, --repo-path, and/or --target flags."
      usage; exit 1
    fi
  else
    pushd $TARGETDIR >/dev/null
    if [[ $(git rev-parse --abbrev-ref HEAD 2>&1 | grep "not a git repo") ]] || [[ ! $(git remote -v 2>&1 | grep github) ]]; then
      echo "Error: $TARGETDIR is not inside a github checkout folder. Must also use --repo and/or --repo-path flags."
      usage; exit 1
    fi
  fi

  all_assets="$(hub release download "${CSV_VERSION}-${ASSET_NAME}-assets" -i LIST 2>&1 | grep -v "pattern did not match" || true)"
  if [[ -n $(echo $all_assets | grep "Unable to find release") ]]; then
      echo "Error: could not find release ${CSV_VERSION}-${ASSET_NAME}-assets in this repo!"
      echo "Error: use --repo, --repo-path, and/or --target flags."
      usage; exit 1
  fi

  if [[ -z $fileList ]]; then 
    echo "Download all assets"
    hub release download "${CSV_VERSION}-${ASSET_NAME}-assets"
  else 
    #attempt to download asset(s)
    for fileToFetch in $fileList; do
      echo "Download asset $fileToFetch"
      hub release download "${CSV_VERSION}-${ASSET_NAME}-assets" -i ${fileToFetch}
    done
  fi

  # if we downloaded assets to the GH folder but want them in the TARGETDIR, move them now
    for d in $all_assets; do 
      if [[ -f $d ]]; then
        if [[ -f $TARGETDIR/$d ]]; then 
          echo "[WARN] Overwrite $TARGETDIR/$d"
        fi
        mv -f $d $TARGETDIR/
      fi
    done
  echo "[INFO] Assets written to $TARGETDIR"

  popd >/dev/null || true

  # cleanup
  rm -fr $TMP
fi
