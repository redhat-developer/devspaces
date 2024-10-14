#!/bin/bash -e
# build all containers in brew, then if successful, copy to quay.

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

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")

usage() {
  echo "
Build all DS containers in Brew with rhpkg container-build (not get-sources*.sh), 
watch the log, and if successful, copy that container to quay.

Usage: $0 [-b ${DWNSTM_BRANCH}] [-t ${DS_VERSION}] --sources [root dir where projects are checked out; if not set, generate /tmp/tmp.* dir]
Example: $0 -t ${DS_VERSION} --sources /path/to/pkgs.devel/projects/
"
  exit
}

latestNext="--latest"
if [[ ${DWNSTM_BRANCH} == "devspaces-3-rhel-8" ]]; then latestNext="--next"; fi

PHASES="1 2"
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') DS_VERSION="$2"; shift 1;;
    '-b') DWNSTM_BRANCH="$2"; shift 1;;
    '--phases'|'-p') PHASES="$2"; shift 1;;
    '--sources'|'-s') SOURCEDIR="$2"; shift 1;;
    '-h') usage;;
  esac
  shift 1
done

if [[ ${DS_VERSION} == "3.y" ]]; then echo "DS version / tag cannot be 3.y; please set a real version like 2.7"; usage; fi

if [[ ! $SOURCEDIR ]]; then SOURCEDIR=$(mktemp -d); fi
pushd $SOURCEDIR >/dev/null || exit 1
echo "[INFO] Check out DS ${DS_VERSION} sources from ${DWNSTM_BRANCH} branches to $SOURCEDIR"

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
        projname=${d/devspaces-/}; 
        pushd ${d} >/dev/null || exit 1
            # switch to correct branch
            git checkout ${DWNSTM_BRANCH} || exit 1
            git pull
            # build
            "${SCRIPTPATH}"/buildInBrewCopyToQuay.sh ${projname} ${latestNext} -t ${DS_VERSION} &
        popd >/dev/null || exit 1
    done
    wait
    # shellcheck disable=2086
    echo "[INFO] Build(s) done for "${projects}
    echo "--------------------------"
    echo
}

if [[ $PHASES == *"1"* ]]; then 
    doBuild "devspaces-code \
        devspaces-configbump \
        devspaces-dashboard \
        devspaces-jetbrains-ide \
        devspaces-idea \
        devspaces-imagepuller \
        devspaces-machineexec \
        devspaces-operator \
        devspaces-pluginregistry \
        devspaces-server \
        devspaces-traefik \
        devspaces-udi"
fi

# operator-bundle is built last after everything else is done
if [[ $PHASES == *"2"* ]]; then 
    doBuild "devspaces-operator-bundle"
fi

# clean up checked out sources
# echo "[INFO] sources checked out into $SOURCEDIR"
rm -fr $SOURCEDIR
