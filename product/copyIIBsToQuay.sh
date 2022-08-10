#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# script to query latest IIBs for a given list of OCP versions, then copy those to Quay
# OPM 4.10 is required to run filterIIBForDevSpaces.sh
# 

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)

usage () {
	echo "Query latest IIBs for a Dev Spaces version and optional list of OCP versions, then filter and copy those IIBs to Quay

Requires:
* jq 1.6+, skopeo 1.1.1+, podman 2.0+, glibc 2.28+
* opm v1.19.5+ (see https://docs.openshift.com/container-platform/4.10/cli_reference/opm/cli-opm-install.html#cli-opm-install )

Usage: 
  $0 [OPTIONS]

Options:
  -p, --push                 : Push IIB(s) to quay registry; default is to show commands but not copy anything
  --force                    : If target image exists, will re-filter and re-push it; otherwise skip to avoid updating image timestamps
  -t PROD_VER                : If x.y version/tag not set, will compute from dependencies/job-config.json file
  -o 'OCP_VER1 OCP_VER2 ...' : Space-separated list of OCP version(s) to query and publish; defaults to job-config.json values
  -e, --extra-tags           : Extra tags to create, such as 3.2.0.RC-08-04
  -v                         : Verbose output: include additional information
  -h, --help                 : Show this help
"
}

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then echo "[ERROR] podman is not installed. Aborting."; echo; usage; exit 1; fi
command -v skopeo >/dev/null 2>&1 || which skopeo >/dev/null 2>&1 || { echo "skopeo is not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1     || which jq >/dev/null 2>&1     || { echo "jq is not installed. Aborting."; exit 1; }

VERBOSEFLAG=""
EXTRA_TAGS="" # extra tags to set in target image, eg., 3.2.0.RC-08-04-v4.10
PUSHTOQUAYFORCE=0

MIDSTM_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "devspaces-3-rhel-8")
if [[ ${MIDSTM_BRANCH} != "devspaces-"*"-rhel-"* ]]; then MIDSTM_BRANCH="devspaces-3-rhel-8"; fi

if [[ -f dependencies/job-config.json ]]; then
    jobconfigjson=dependencies/job-config.json
elif [[ -f ${SCRIPT_DIR}/../dependencies/job-config.json ]]; then
    jobconfigjson=${SCRIPT_DIR}/../dependencies/job-config.json
else
    pushd /tmp >/dev/null 
    curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/${MIDSTM_BRANCH}/dependencies/job-config.json
    jobconfigjson=/tmp/job-config.json
    popd >/dev/null
fi

# collect defaults from dependencies/job-config.json file
# product Version 
DS_VERSION=$(jq -r '.Version' ${jobconfigjson})

setDefaults() {
    # list of OCP versions 
    OCP_VERSIONS_DEFAULT="$(jq -r --arg VERSION "${DS_VERSION}" '.Other.OPENSHIFT_VERSIONS_SUPPORTED[$VERSION]|@tsv' ${jobconfigjson} | tr "\t" " ")"
    if [[ $OCP_VERSIONS_DEFAULT == "null" ]]; then OCP_VERSIONS_DEFAULT=""; fi
    # next or latest tag to set
    FLOATING_QUAY_TAGS="$(jq -r --arg VERSION "${DS_VERSION}" '.Other.FLOATING_QUAY_TAGS[$VERSION]' ${jobconfigjson})" 
    if [[ $FLOATING_QUAY_TAGS == "null" ]]; then FLOATING_QUAY_TAGS=""; fi
}
setDefaults

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') DS_VERSION="$2"; setDefaults; shift 1;;
    '-o') if [[ "$2" != "v"* ]]; then OCP_VERSIONS="${OCP_VERSIONS} v${2}"; else OCP_VERSIONS="${OCP_VERSIONS} ${2}"; fi; shift 1;;
    '-e'|'--extra-tags') EXTRA_TAGS="${EXTRA_TAGS} ${2}"; shift 1;;
    '-v') VERBOSEFLAG="-v"; shift 0;;
    '-p'|'--push') PUSH="true";;
    '--force') PUSHTOQUAYFORCE=1;;
    '-h'|'--help') usage; exit 0;;
    *) echo "Unknown parameter used: $1."; usage; exit 1;;
  esac
  shift 1
done

if [[ ! $OCP_VERSIONS ]]; then OCP_VERSIONS="${OCP_VERSIONS_DEFAULT}"; fi
for o in $OCP_VERSIONS; do if [[ $OCP_UNIQ != *" $o"* ]];then OCP_UNIQ="${OCP_UNIQ} $o"; fi; done
OCP_VERSIONS="$OCP_UNIQ"

# fail if DS_VERSION is not set
if [[ $DS_VERSION == "" ]] || [[ $DS_VERSION == "null" ]]; then 
    echo "Error reading Version from ${jobconfigjson}! Must use -t flag to set x.y version"
    exit 1
fi

if [[ $VERBOSEFLAG == "-v" ]]; then 
	echo "[DEBUG] DS_VERSION=${DS_VERSION}"
	echo "[DEBUG] MIDSTM_BRANCH = $MIDSTM_BRANCH"
	echo "[DEBUG] OCP_VERSIONS = ${OCP_VERSIONS}"
	echo "[DEBUG] FLOATING_QUAY_TAGS = $FLOATING_QUAY_TAGS"
    if [[ $EXTRA_TAGS ]]; then echo "[DEBUG] EXTRA_TAGS = $EXTRA_TAGS"; fi
fi

# install opm if not installed from https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.10/
if [[ ! -x /usr/local/bin/opm ]] && [[ ! -x ${HOME}/.local/bin/opm ]]; then 
    pushd /tmp >/dev/null
    OPM_TAR=$(curl -sSLo- https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.10/sha256sum.txt | grep opm-linux | sed -r -e "s#.+  ##")
    echo "[INFO] Installing $OPM_TAR ..."
    curl -sSLo- https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.10/${OPM_TAR} | tar xz; chmod 755 opm
    sudo cp opm /usr/local/bin/ || cp opm ${HOME}/.local/bin/
    if [[ ! -x /usr/local/bin/opm ]] && [[ ! -x ${HOME}/.local/bin/opm ]]; then 
        echo "[ERROR] Could not install opm v1.19.5 or higher (see https://docs.openshift.com/container-platform/4.10/cli_reference/opm/cli-opm-install.html#cli-opm-install )";
        exit 1
    fi
    popd >/dev/null
fi

checkVersion() {
  if [[  "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]]; then
    # echo "[INFO] $3 version $2 >= $1, can proceed."
	true
  else 
    echo "[ERROR] Must install $3 version >= $1"
    exit 1
  fi
}
checkVersion 1.1 "$(skopeo --version | sed -e "s/skopeo version //")" skopeo

if [[ -x ${SCRIPT_DIR}/getLatestIIBs.sh ]]; then
    GLIB=${SCRIPT_DIR}/getLatestIIBs.sh
else 
    pushd /tmp >/dev/null 
    curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/${MIDSTM_BRANCH}/product/getLatestIIBs.sh && chmod +x getLatestIIBs.sh
    GLIB=/tmp/getLatestIIBs.sh
    popd >/dev/null
fi

if [[ -x ${SCRIPT_DIR}/filterIIBForDevSpaces.sh ]]; then
    FIIB=${SCRIPT_DIR}/filterIIBForDevSpaces.sh
else 
    pushd /tmp >/dev/null 
    curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/${MIDSTM_BRANCH}/product/filterIIBForDevSpaces.sh && chmod +x filterIIBForDevSpaces.sh
    FIIB=/tmp/filterIIBForDevSpaces.sh
    popd >/dev/null
fi

if [[ "$PUSH" != "true" ]]; then
    echo "To filter and publish IIBs, copy the commands below, or re-run using --push flag."
    echo
fi

# compute list of IIBs for a given operator bundle
for OCP_VER in ${OCP_VERSIONS}; do
    PUSHTOQUAYFORCE_LOCAL=${PUSHTOQUAYFORCE}
    # registry-proxy.engineering.redhat.com/rh-osbs/iib:286641
    LATEST_IIB=$(${GLIB} --ds -t ${DS_VERSION} -o ${OCP_VER} -qi) # return quietly, just the index bundle
    LATEST_IIB_NUM=${LATEST_IIB##*:}
    if [[ $VERBOSEFLAG == "-v" ]]; then 
        echo "[DEBUG] OPERATOR_BUNDLE=$(${GLIB} --ds -t ${DS_VERSION} -o ${OCP_VER} -qb)"
        echo "[DEBUG]  IIB FOR BUNDLE=${LATEST_IIB}"
    fi

    if [[ "$PUSH" == "true" ]]; then
        # check if destination already exists in quay
        if [[ $(skopeo --insecure-policy inspect docker://quay.io/devspaces/iib:${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM} 2>&1) == *"Error"* ]] || [[ ${PUSHTOQUAYFORCE} -eq 1 ]]; then 
            # filter and publish to a new name
            ${FIIB} -s ${LATEST_IIB} -t quay.io/devspaces/iib:${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM} --push --list-copies-only ${VERBOSEFLAG}
        else
            if [[ $VERBOSEFLAG == "-v" ]]; then echo "Copy quay.io/devspaces/iib:${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM} - already exists, nothing to do"; fi
        fi
        PUSHTOQUAYFORCE_LOCAL=1
    else
        echo "${FIIB} -s ${LATEST_IIB} -t quay.io/devspaces/iib:${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM} --push"
    fi

    if [[ $(skopeo --insecure-policy inspect docker://quay.io/devspaces/iib:${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM} 2>&1) == *"Error"* ]]; then 
        echo "[ERROR] Cannot find image quay.io/devspaces/iib:${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM} to copy!"
        echo "[ERROR] Check output of this command for an idea of what went wrong:"
        echo "[ERROR] ${FIIB} -s ${LATEST_IIB} -t quay.io/devspaces/iib:${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM} -v --push"
        exit 1
    fi

    # skopeo copy to additional tags
    ALL_TAGS="${DS_VERSION}-${OCP_VER}"
    for atag in $FLOATING_QUAY_TAGS; do 
        ALL_TAGS="${ALL_TAGS} ${atag}-${OCP_VER}"
    done
    for atag in $EXTRA_TAGS; do 
        ALL_TAGS="${ALL_TAGS} ${atag}-${OCP_VER}"
    done

    for qtag in ${ALL_TAGS}; do
        if [[ $(skopeo --insecure-policy inspect docker://quay.io/devspaces/iib:${qtag} 2>&1) == *"Error"* ]] || [[ ${PUSHTOQUAYFORCE_LOCAL} -eq 1 ]]; then 
            CMD="skopeo --insecure-policy copy --all docker://quay.io/devspaces/iib:${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM} docker://quay.io/devspaces/iib:${qtag}"
            if [[ $VERBOSE -eq 1 ]]; then
                echo $CMD
                if [[ "$PUSH" == "true" ]]; then $CMD; fi
            else
                if [[ "$PUSH" == "true" ]]; then $CMD -q; fi
                echo "[IMG] quay.io/devspaces/iib:${qtag}"
            fi
        else
            if [[ $VERBOSEFLAG == "-v" ]]; then echo "Copy quay.io/devspaces/iib:${qtag} - already exists, nothing to do"; fi
        fi
    done

    # cleanup images
    $PODMAN rmi --ignore --force ${LATEST_IIB} $targetIndexImage >/dev/null 2>&1 || true
done

# cleanup temp space 
rm -fr /tmp/render-registry* /tmp/tmp.*
