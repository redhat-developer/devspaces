#!/bin/bash

# script to collect 3rd party binaries we can't build, and push them to download.devel so they can be used in builds
#!/bin/bash

# script to fetch PNC artifacts from the latest successful job, then copy those artifacts to spmm-util.

# requires:
    # spmm-util-users account - see https://issues.redhat.com/browse/SPMM-13576 and https://spmm.pages.redhat.com/util-ansible/#access-prerequisites
    # curl
    # rsync

set -e

ARCHES=""
VERSION=""
DEBUG=0
PUBLISH=0 # by default don't publish to spmm-util

REMOTE_USER_AND_HOST="devspaces-build@spmm-util.engineering.redhat.com"

usage () 
{
    echo "
Usage: $0 -u baseurl -a artifactname -v x.y.z [--arches \"list of arches\"] [--debug] -[w WORKSPACE_DIR]

Options:
    --publish                             publish GA bits for a release to $REMOTE_USER_AND_HOST
    --desthost user@destination-host      specific an alternate destination host for publishing

Example: 
$0 -u https://github.com/microsoft/ripgrep-prebuilt/releases/download -ad ripgrep-multiarch -as ripgrep \
    --arches \"x86_64-unknown-linux-musl s390x-unknown-linux-gnu powerpc64le-unknown-linux-gnu\" \
    --debug --publish -v v13.0.0-7
"
    exit
}

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-u') BASEURL="$2"; shift 1;;
    '-ad') ARTIFACTDIRNAME="$2"; shift 1;;
    '-as') ARTIFACTSHORTNAME="$2"; shift 1;;
    '-v') VERSION="$2"; shift 1;; # 3.y.0
    '--arches') ARCHES="$ARCHES $2"; shift 1;;
    '--publish') PUBLISH=1;;
    '--desthost') REMOTE_USER_AND_HOST="$2"; shift 1;;
    '--debug') DEBUG=1;;
    '-w') WORKSPACE="$2"; shift 1;;
  esac
  shift 1
done

if [[ ! "${WORKSPACE}" ]]; then WORKSPACE=/tmp; fi
if [[ ! "${BASEURL}" ]]; then echo "Must set BASEURL with -u flag"; usage; fi
if [[ ! "${ARTIFACTDIRNAME}" ]]; then echo "Must set ARTIFACTDIRNAME with -ad flag"; usage; fi
if [[ ! "${ARTIFACTSHORTNAME}" ]]; then echo "Must set ARTIFACTSHORTNAME with -as flag"; usage; fi
if [[ ! "${VERSION}" ]]; then echo "Must set VERSION with -v flag"; usage; fi
if [[ ! "${ARCHES}" ]]; then echo "Must set ARCHES with --arches flag"; usage; fi

FOLDER_PREFIX="build-requirements/common/${ARTIFACTDIRNAME}/${VERSION}"
TODAY_DIR="${WORKSPACE}/${FOLDER_PREFIX}"

mkdir -p "${TODAY_DIR}"; cd "${TODAY_DIR}"
if [[ $DEBUG -eq 1 ]]; then
    echo "Working in $TODAY_DIR ..."
fi

# fetch those artifacts from https://github.com/microsoft/ripgrep-prebuilt/releases/download/v13.0.0-7/ripgrep-v13.0.0-7-powerpc64le-unknown-linux-gnu.tar.gz
for arch in $ARCHES; do
    url="${BASEURL}/${VERSION}/${ARTIFACTSHORTNAME}-${VERSION}-${arch}.tar.gz"
    if [[ $DEBUG -eq 1 ]]; then
        echo "Fetch $url ..."
    fi
    curl -sSLkO "$url"
done

# optionally, push files to spmm-util server as part of a GA release
if [[ $PUBLISH -eq 1 ]]; then
    set -x
    # ssh spmm-util mkdir staging/devspaces/build-requirements/common
    rsync -rlP "${TODAY_DIR}" "${REMOTE_USER_AND_HOST}:staging/devspaces/build-requirements/common/"
    set +x
fi
