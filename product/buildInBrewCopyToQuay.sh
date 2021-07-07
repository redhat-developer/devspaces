#!/bin/bash -e
# build a container in brew, then if successful, copy to quay.

# to run for multiple repos checked out locally...
# $➔ for d in $(ls -1 -d stacks-*); do cd $d; { ../buildInBrewCopyToQuay.sh $d; }; cd ..; done
# $➔ for d in $(ls -1 -d plugin-*); do cd $d; { ../buildInBrewCopyToQuay.sh $d; }; cd ..; done

# TODO should we invoke this and commit changes first?
# /path/to/product/getLatestRPM.sh -s "$(pwd)" -r openshift-clients-4 -u http://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/basearch/rhocp/4.7 -a "x86_64 s390x ppc64le" 
# /path/to/product/getLatestRPM.sh -s "$(pwd)" -r helm-3 -u http://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/basearch/ocp-tools/4.7 -a "x86_64 s390x ppc64le" 

# try to compute branches from currently checked out branch; else fall back to hard coded value
# where to find redhat-developer/codeready-workspaces/${DWNSTM_BRANCH}/product/getLatestImageTags.sh
CRW_VERSION="2.y"
DWNSTM_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ $DWNSTM_BRANCH != "crw-2."*"-rhel-8" ]]; then
  DWNSTM_BRANCH="crw-2-rhel-8"
else 
  CRW_VERSION=${DWNSTM_BRANCH/crw-/}; CRW_VERSION=${CRW_VERSION/-rhel-8/}
fi

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")

usage() {
  echo "
Build a container in Brew with rhpkg container-build (not get-sources*.sh), 
watch the log, and if successful, copy that container to quay.

Usage: $0 image-name [-b ${DWNSTM_BRANCH}] [-t ${CRW_VERSION}] [--latest] [--nightly]
Example: $0 configbump -t ${CRW_VERSION}

Options: 
    --nightly    in addition to the :${CRW_VERSION} tag, also update :nightly tag
    --latest     in addition to the :${CRW_VERSION} tag, also update :latest tag
"
  exit
}

latestNightly="latest"
if [[ ${DWNSTM_BRANCH} == "crw-2-rhel-8" ]]; then latestNightly="nightly"; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') CRW_VERSION="$2"; shift 1;;
    '-b') DWNSTM_BRANCH="$2"; shift 1;;
    '--latest') latestNightly="latest";;
    '--nightly') latestNightly="nightly";;
    '-h') usage;;
    *) IMG=$1;;
  esac
  shift 1
done

if [[ ! ${IMG} ]]; then usage; fi
if [[ ${CRW_VERSION} == "2.y" ]]; then echo "CRW version / tag cannot be 2.y; please set a real version like 2.7"; usage; fi

set -x

git fetch;git pull origin $DWNSTM_BRANCH || true

brewTaskID=$(rhpkg container-build --nowait | sed -r -e "s#.+: ##" | head -1)
if [[ $brewTaskID ]]; then 
  google-chrome "https://brewweb.engineering.redhat.com/brew/taskinfo?taskID=${brewTaskID}"
  brew watch-logs ${brewTaskID} | tee /tmp/${brewTaskID}.txt

  container="codeready-workspaces-${IMG}-rhel8"
  if [[ $container == *"operator"* ]]; then container="codeready-workspaces-${IMG}"; fi # special case for operator & metadata images

  grep -E "registry.access.redhat.com/codeready-workspaces/.+/images/${CRW_VERSION}-[0-9]+" /tmp/${brewTaskID}.txt | \
    grep -E "setting label" | \
    sed -r -e "s@.+(registry.access.redhat.com/codeready-workspaces/)(.+)/images/(${CRW_VERSION}-[0-9]+)\"@\2:\3@g" | \
    tr -d "'" | tail -1 && \
  ${SCRIPTPATH}/getLatestImageTags.sh -b ${DWNSTM_BRANCH} --osbs --pushtoquay="${CRW_VERSION} ${latestNightly}" -c $container
fi
