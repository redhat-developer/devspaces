#!/bin/bash -e
# build all containers in brew, then if successful, copy to quay.

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
Build all CRW containers in Brew with rhpkg container-build (not get-sources*.sh), 
watch the log, and if successful, copy that container to quay.

Usage: $0 [-b ${DWNSTM_BRANCH}] [-t ${CRW_VERSION}] --sources [root dir where projects are checked out; if not set, generate /tmp/tmp.* dir]
Example: $0 -t ${CRW_VERSION} --sources /path/to/pkgs.devel/projects/
"
  exit
}

latestNightly="--latest"
if [[ ${DWNSTM_BRANCH} == "crw-2-rhel-8" ]]; then latestNightly="--nightly"; fi

PHASES="1 2 3 4 5 6"
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') CRW_VERSION="$2"; shift 1;;
    '-b') DWNSTM_BRANCH="$2"; shift 1;;
    '--phases'|'-p') PHASES="$2"; shift 1;;
    '--sources'|'-s') SOURCEDIR="$2"; shift 1;;
    '-h') usage;;
  esac
  shift 1
done

if [[ ${CRW_VERSION} == "2.y" ]]; then echo "CRW version / tag cannot be 2.y; please set a real version like 2.7"; usage; fi

if [[ ! $SOURCEDIR ]]; then SOURCEDIR=$(mktemp -d); fi
pushd $SOURCEDIR >/dev/null || exit 1
echo "[INFO] Check out CRW ${CRW_VERSION} sources from ${DWNSTM_BRANCH} branches to $SOURCEDIR"

doBuild () {
    projects="$1"
    for d in $projects; do
        # get sources
        if [[ ! -d ${SOURCEDIR}/${d} ]]; then 
            echo "[INFO] Check out ${d}"
            git clone ssh://nboldt@pkgs.devel.redhat.com/containers/${d}
        else 
            echo "[INFO] Use existing folder ${d}"
        fi
        projname=${d/codeready-workspaces-/}; 
        projname=${projname/codeready-workspaces/server} # special case
        pushd ${d} >/dev/null || exit 1
            # switch to correct branch
            git checkout ${DWNSTM_BRANCH} || exit 1
            git pull
            # build
            "${SCRIPTPATH}"/buildInBrewCopyToQuay.sh ${projname} ${latestNightly} -t ${CRW_VERSION} &
        popd >/dev/null || exit 1
    done
    wait
    # shellcheck disable=2086
    echo "[INFO] Build(s) done for "${projects}
    echo "--------------------------"
    echo
}
if [[ $PHASES == *"1"* ]]; then 
    doBuild codeready-workspaces-imagepuller
fi

# TODO implement offline build of crw-deprecated assets :(
if [[ $PHASES == *"2"* ]]; then 
    echo "TODO implement offline build of crw-deprecated assets :("
fi

if [[ $PHASES == *"3"* ]]; then 
    doBuild "codeready-workspaces-plugin-java11-openj9 \
        codeready-workspaces-plugin-java11 \
        codeready-workspaces-plugin-java8-openj9 \
        codeready-workspaces-plugin-java8 \
        codeready-workspaces-plugin-kubernetes \
        codeready-workspaces-plugin-openshift \
        codeready-workspaces-stacks-cpp \
        codeready-workspaces-stacks-dotnet \
        codeready-workspaces-stacks-golang \
        codeready-workspaces-stacks-php"
fi

if [[ $PHASES == *"4"* ]]; then 
    doBuild codeready-workspaces-theia-dev
    doBuild codeready-workspaces-theia
    doBuild codeready-workspaces-theia-endpoint
fi

if [[ $PHASES == *"5"* ]]; then 
    doBuild "codeready-workspaces \
        codeready-workspaces-dashboard \
        codeready-workspaces-devworkspace-controller \
        codeready-workspaces-devworkspace \
        codeready-workspaces-configbump \
        codeready-workspaces-jwtproxy \
        codeready-workspaces-machineexec \
        codeready-workspaces-operator \
        codeready-workspaces-pluginbroker-artifacts \
        codeready-workspaces-pluginbroker-metadata \
        codeready-workspaces-traefik"
fi

if [[ $PHASES == *"6"* ]]; then 
    doBuild "codeready-workspaces-devfileregistry \
            codeready-workspaces-pluginregistry"
    doBuild codeready-workspaces-operator-metadata
fi

# clean up checked out sources
echo "[INFO] sources checked out into $SOURCEDIR"
# rm -fr $SOURCEDIR
