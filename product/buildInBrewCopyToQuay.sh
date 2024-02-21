#!/bin/bash -e
# build a container in brew, then if successful, copy to quay.

# to run for multiple repos checked out locally...
# $➔ for d in $(ls -1 -d operator-*); do cd $d; { ../buildInBrewCopyToQuay.sh $d; }; cd ..; done

# TODO should we invoke this and commit changes first?
# /path/to/product/getLatestRPM.sh -s "$(pwd)" -r openshift-clients-4 -u https://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/basearch/rhocp/4.7 -a "x86_64 s390x ppc64le" 
# /path/to/product/getLatestRPM.sh -s "$(pwd)" -r helm-3 -u https://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/basearch/ocp-tools/4.7 -a "x86_64 s390x ppc64le" 

# try to compute branches from currently checked out branch; else fall back to hard coded value
# where to find redhat-developer/devspaces/${DWNSTM_BRANCH}/product/getLatestImageTags.sh
DS_VERSION="3.y"
DWNSTM_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ $DWNSTM_BRANCH != "devspaces-3."*"-rhel-8" ]]; then
  DWNSTM_BRANCH="devspaces-3-rhel-8"
else 
  DS_VERSION=${DWNSTM_BRANCH/devspaces-/}; DS_VERSION=${DS_VERSION/-rhel-8/}
fi
BUILD_DIR=$(pwd)
SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")

usage() {
  echo "
Build a container in Brew with rhpkg container-build (not get-sources*.sh), 
watch the log, and if successful, copy that container to quay.

Usage: $0 image-name [-b ${DWNSTM_BRANCH}] [-t ${DS_VERSION}] [--latest] [--next]
Example: $0 configbump -t ${DS_VERSION}

Options: 
    --next             in addition to the :${DS_VERSION} tag, also update :next tag
    --latest           in addition to the :${DS_VERSION} tag, also update :latest tag
    --pull-assets, -p  run get-sources.sh
"
  exit
}

latestNext="latest"
if [[ ${DWNSTM_BRANCH} == "devspaces-3-rhel-8" ]]; then latestNext="next"; fi

pullAssets=0
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') DS_VERSION="$2"; shift 1;;
    '-b') DWNSTM_BRANCH="$2"; shift 1;;
    '--latest') latestNext="latest";;
    '--next') latestNext="next";;
    '-p'|'--pull-assets') pullAssets=1; shift 0;;
    '-h') usage;;
    *) IMG=$1;;
  esac
  shift 1
done

if [[ ! ${IMG} ]]; then usage; fi
if [[ ${DS_VERSION} == "3.y" ]]; then echo "DS version / tag cannot be 3.y; please set a real version like 2.7"; usage; fi

set -x

git fetch;git pull origin $DWNSTM_BRANCH || true

if [[ $pullAssets -eq 1 ]]; then
  if [[ -f "${BUILD_DIR}"/get-sources.sh ]]; then
    brewTaskID=$("${BUILD_DIR}"/get-sources.sh -f -p "$DS_VERSION")
  elif [[ -f "${BUILD_DIR}"/get-sources-jenkins.sh ]]; then
    brewTaskID=$("${BUILD_DIR}"/get-sources-jenkins.sh -f -p "$DS_VERSION")
  else
    echo "Error: cannot find ${BUILD_DIR}/get-sources*.sh to run!"
    exit 1
  fi
else
  brewTaskID=$(rhpkg container-build --nowait | sed -r -e "s#.+: ##" | head -1)
fi

if [[ $brewTaskID ]]; then 
  google-chrome "https://brewweb.engineering.redhat.com/brew/taskinfo?taskID=${brewTaskID}"
  brew watch-logs ${brewTaskID} | tee /tmp/${brewTaskID}.txt

  container="devspaces-${IMG}-rhel8"
  if [[ $container == *"operator"* ]]; then container="devspaces-${IMG}"; fi # special case for operator & metadata images

  grep -E "registry.access.redhat.com/devspaces/.+/images/${DS_VERSION}-[0-9]+" /tmp/${brewTaskID}.txt | \
    grep -E "setting label" | \
    sed -r -e "s@.+(registry.access.redhat.com/devspaces/)(.+)/images/(${DS_VERSION}-[0-9]+)\"@\2:\3@g" | \
    tr -d "'" | tail -1 && \
  ${SCRIPTPATH}/getLatestImageTags.sh -b ${DWNSTM_BRANCH} --osbs --pushtoquay="${DS_VERSION} ${latestNext}" -c $container
fi
