#!/bin/bash
#
# Copyright (c) 2022-2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# script to query latest IIBs for a given list of OCP versions, then copy those to Quay
# OPM from 4.12 (>v1.26.3 upstream version) is required to run buildCatalog.sh (CRW-4192, OCPBUGS-11841)
#

SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)

usage () {
	echo "Query latest IIBs for a Dev Spaces version and optional list of OCP versions, then filter and copy those IIBs to Quay

Requires:
* jq 1.6+, skopeo 1.1.1+, podman 2.0+, glibc 2.28+
* opm v1.26.3+ (see https://docs.openshift.com/container-platform/4.12/cli_reference/opm/cli-opm-install.html#cli-opm-install )

Usage:
  $0 [OPTIONS]

Options:
  -p, --push                 : Push IIB(s) to quay registry; default is to show commands but not copy anything
  --force                    : If target image exists, will re-filter and re-push it; otherwise skip to avoid updating image timestamps
  -t PROD_VER                : If x.y version/tag not set, will compute from dependencies/job-config.json file
  -o 'OCP_VER1 OCP_VER2 ...' : Space-separated list of OCP version(s) (e.g. 'v4.13 v4.12') to query and publish; defaults to job-config.json values
  -e, --extra-tags           : Extra tags to create, such as 3.5.0.RC-02-21-v4.13-x86_64
  -v                         : Verbose output: include additional information
  -h, --help                 : Show this help
"
}

if [[ "$#" -lt 1 ]]; then usage; exit 1; fi

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then echo "[ERROR] podman is not installed. Aborting."; echo; usage; exit 1; fi
command -v skopeo >/dev/null 2>&1 || which skopeo >/dev/null 2>&1 || { echo "skopeo is not installed. Aborting."; exit 1; }
command -v jq >/dev/null 2>&1     || which jq >/dev/null 2>&1     || { echo "jq is not installed. Aborting."; exit 1; }

VERBOSEFLAG=""
EXTRA_TAGS="" # extra tags to set in target image, eg., 3.5.0.RC-02-21-v4.13-x86_64
PUSHTOQUAYFORCE=0
targetIndexImage=""

MIDSTM_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "devspaces-3-rhel-8")
if [[ ${MIDSTM_BRANCH} != "devspaces-"*"-rhel-"* ]]; then MIDSTM_BRANCH="devspaces-3-rhel-8"; fi

if [[ -f dependencies/job-config.json ]]; then
    jobconfigjson=dependencies/job-config.json
elif [[ -f ${SCRIPT_DIR}/../dependencies/job-config.json ]]; then
    jobconfigjson=${SCRIPT_DIR}/../dependencies/job-config.json
else
    pushd /tmp >/dev/null || exit
    curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/"${MIDSTM_BRANCH}"/dependencies/job-config.json
    jobconfigjson=/tmp/job-config.json
    popd >/dev/null || exit 
fi

# collect defaults from dependencies/job-config.json file
# product Version
DS_VERSION=$(jq -r '.Version' "${jobconfigjson}")
DWO_VERSION=$(jq -r --arg VERSION "${DS_VERSION}" '.Other.DEV_WORKSPACE_OPERATOR_TAG[$VERSION]' "${jobconfigjson}")
if [[ $DWO_VERSION == "null" ]]; then DWO_VERSION="0."; fi

setDefaults() {
    # list of OCP versions
    OCP_VERSIONS_DEFAULT="$(jq -r --arg VERSION "${DS_VERSION}" '.Other.OPENSHIFT_VERSIONS_SUPPORTED[$VERSION]|@tsv' "${jobconfigjson}" | tr "\t" " ")"
    if [[ $OCP_VERSIONS_DEFAULT == "null" ]]; then OCP_VERSIONS_DEFAULT=""; fi
    # next or latest tag to set
    FLOATING_QUAY_TAGS="$(jq -r --arg VERSION "${DS_VERSION}" '.Other.FLOATING_QUAY_TAGS[$VERSION]' "${jobconfigjson}")"
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
	echo "[DEBUG] DWO_VERSION=${DWO_VERSION}"
	echo "[DEBUG] MIDSTM_BRANCH = $MIDSTM_BRANCH"
	echo "[DEBUG] OCP_VERSIONS  =${OCP_VERSIONS}"
	echo "[DEBUG] FLOATING_QUAY_TAGS = $FLOATING_QUAY_TAGS"
    if [[ $EXTRA_TAGS ]]; then echo "[DEBUG] EXTRA_TAGS = $EXTRA_TAGS"; fi
fi

# install opm if not installed by ansible https://gitlab.cee.redhat.com/codeready-workspaces/ansible-scripts/-/blob/master/roles/users/tasks/profile-hudson/main.yml#L107 to /usr/local/bin/opm
if [[ ! -x /usr/local/bin/opm ]] && [[ ! -x "${HOME}"/.local/bin/opm ]]; then
    pushd /tmp >/dev/null || exit
    echo "[INFO] Installing latest opm from https://mirror.openshift.com/pub/openshift-v4/$(uname -m)/clients/ocp/latest-4.12/opm-linux.tar.gz ..."
    curl -sSLo- "https://mirror.openshift.com/pub/openshift-v4/$(uname -m)/clients/ocp/latest-4.12/opm-linux.tar.gz" | tar xz; chmod 755 opm
    sudo cp opm /usr/local/bin/ || cp opm "${HOME}"/.local/bin/
    sudo chmod 755 /usr/local/bin/opm || chmod 755 "${HOME}"/.local/bin/opm
    if [[ ! -x /usr/local/bin/opm ]] && [[ ! -x "${HOME}"/.local/bin/opm ]]; then
        echo "[ERROR] Could not install opm v1.26.3 or higher (see https://docs.openshift.com/container-platform/4.12/cli_reference/opm/cli-opm-install.html#cli-opm-install )";
        exit 1
    fi
    popd >/dev/null || exit
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

getScript () {
    scriptFile=$1
    if [[ -x ${SCRIPT_DIR}/"${scriptFile}" ]]; then
        getScript_return=${SCRIPT_DIR}/"${scriptFile}"
    else
        if [[ $VERBOSEFLAG == "-v" ]]; then echo "Downloading ${scriptFile} script from Github"; fi
        pushd /tmp >/dev/null || exit
        curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/"${MIDSTM_BRANCH}"/product/"${scriptFile}" && \
        chmod +x "${scriptFile}"
        getScript_return=/tmp/"${scriptFile}"
        popd >/dev/null || exit
    fi
}

# TODO remove this script if we no longer need it because getIIBsForBundle works better / faster
getScript getLatestIIBs.sh;      getLatestIIBs=${getScript_return}

getScript getIIBsForBundle.sh;   getIIBsForBundle=${getScript_return}
getScript getLatestImageTags.sh; getLatestImageTags=${getScript_return}
getScript filterIIB.sh;          filterIIB=${getScript_return}
getScript buildCatalog.sh;       buildCatalog=${getScript_return}

if [[ "$PUSH" != "true" ]]; then
    echo "To filter and publish IIBs, copy the commands below, or re-run using --push flag."
    echo
fi

# compute list of IIBs for a given operator bundle
for OCP_VER in ${OCP_VERSIONS}; do
    PUSHTOQUAYFORCE_LOCAL=${PUSHTOQUAYFORCE}
    # registry-proxy.engineering.redhat.com/rh-osbs/iib:286641
    LATEST_IIB=$(${getIIBsForBundle}  --ds -t "${DS_VERSION}" -o "${OCP_VER}" -qi | sort -uV | tail -1) # return quietly, just the index bundle
    if [[ ! $LATEST_IIB ]] || [[ $LATEST_IIB == *"Could not fetch ref_url"* ]]; then # fall back to getLatestIIBs.sh
        LATEST_IIB=$(${getLatestIIBs} --ds -t "${DS_VERSION}" -o "${OCP_VER}" -qi | sort -uV | tail -1) # return quietly, just the index bundle
    fi
    LATEST_IIB_NUM=${LATEST_IIB##*:}
    # Get DevWorkspace Operator IIB separately to enable DWO RC testing
    # don't wait the usual 30 mins to see if new DWO is published; instead just check once and give up if not found
    LATEST_DWO_IIB=$(${getIIBsForBundle}  --dwo -t "${DWO_VERSION}" -c 'devworkspace-operator-bundle' -o "${OCP_VER}" -qi | sort -uV | tail -1) # return quietly, just the index bundle
    if [[ ! $LATEST_DWO_IIB ]] || [[ $LATEST_DWO_IIB == *"Could not fetch ref_url"* ]]; then # fall back to getLatestIIBs.sh
        LATEST_DWO_IIB=$(${getLatestIIBs} --dwo -t "${DWO_VERSION}" -c 'devworkspace-operator-bundle' -o "${OCP_VER}" -qi --timeout 2 --interval 1 | sort -uV | tail -1) # return quietly, just the index bundle
    fi
    LATEST_DWO_IIB_NUM=${LATEST_DWO_IIB##*:}

    # NOTE: this is NOT OCP server arch, but the arch of the local build machine!
    # must build on multiple arches to get per-arch IIBs
    if [[ $LATEST_DWO_IIB_NUM ]]; then
        LATEST_IIB_QUAY="quay.io/devspaces/iib:${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM}-${LATEST_DWO_IIB_NUM}-$(uname -m)"
        CATALOG_DIR=$(mktemp -d --suffix "-${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM}-${LATEST_DWO_IIB_NUM}-$(uname -m)")
    else
         # use simpler tag when no DWO available
        LATEST_IIB_QUAY="quay.io/devspaces/iib:${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM}-$(uname -m)"
        CATALOG_DIR=$(mktemp -d --suffix "-${DS_VERSION}-${OCP_VER}-${LATEST_IIB_NUM}-$(uname -m)")
    fi 

    if [[ $VERBOSEFLAG == "-v" ]]; then
        echo "[DEBUG] LATEST DS  OPERATOR BUNDLE = $(${getLatestImageTags} --osbs -c devspaces-operator-bundle --tag "${DS_VERSION}")"
        echo "[DEBUG] LATEST DWO OPERATOR BUNDLE = $(${getLatestImageTags} --osbs -c devworkspace-operator-bundle --tag "${DWO_VERSION}")"
        echo "[DEBUG] Note that the above bundles might not yet exist for the latest IIB, if still being published."
        echo ""
        echo "[DEBUG] DS     INDEX BUNDLE = ${LATEST_IIB}"
        if [[ $LATEST_DWO_IIB ]] ;then
            echo "[DEBUG] DWO    INDEX BUNDLE = ${LATEST_DWO_IIB}"
        else
            echo "[DEBUG] DWO    INDEX BUNDLE = n/a"
        fi
        echo "[DEBUG] QUAY   INDEX BUNDLE = ${LATEST_IIB_QUAY}"
    fi

    if [[ ! ${LATEST_IIB} ]]; then
        echo "[ERROR] Could not compute index bundle for DS ${DS_VERSION} and OCP ${OCP_VER} !"
        exit 2
    fi

    # filter and publish to a new name, putting all operators in the fast channel
    if [[ $VERBOSEFLAG == "-v" ]]; then echo "[DEBUG] Rendering catalog to: $CATALOG_DIR"; fi
    # if we have a latest DWO IIB, use that for DWO operator
    if [[ $LATEST_DWO_IIB_NUM ]]; then
        ${filterIIB} -s "${LATEST_IIB}" --channel-all fast --dir "$CATALOG_DIR" --packages "devspaces web-terminal" ${VERBOSEFLAG}
        ${filterIIB} -s "${LATEST_DWO_IIB}" --channel-all fast --dir "$CATALOG_DIR" --packages "devworkspace-operator" ${VERBOSEFLAG}
    # or, if no DWO IIB exists, fall back to latest DWO operator in the devspaces IIB
    else 
        ${filterIIB} -s "${LATEST_IIB}" --channel-all fast --dir "$CATALOG_DIR" --packages "devworkspace-operator devspaces web-terminal" ${VERBOSEFLAG}
    fi

    # shellcheck disable=SC2086
    if [[ "$PUSH" != "true" ]]; then
        ${buildCatalog} -t "${LATEST_IIB_QUAY}" ${VERBOSEFLAG} --dir "$CATALOG_DIR" --ocp-ver $OCP_VER
        # If we're not pushing, we're done processing the IIB for this OCP_VER -- skopeo inspect and copy fail if the image
        # has not been pushed.
        continue
    fi
    # $PUSH == true
    # check if destination already exists in quay
    # shellcheck disable=SC2086
    if [[ $(skopeo --insecure-policy inspect docker://${LATEST_IIB_QUAY} 2>&1) == *"Error"* ]] || [[ ${PUSHTOQUAYFORCE} -eq 1 ]]; then
        ${buildCatalog} -t ${LATEST_IIB_QUAY} --push ${VERBOSEFLAG} --dir $CATALOG_DIR --ocp-ver $OCP_VER
        PUSHTOQUAYFORCE_LOCAL=1
    else
        if [[ $VERBOSEFLAG == "-v" ]]; then echo "Copy ${LATEST_IIB_QUAY} - already exists, nothing to do"; fi
        echo "[IMG] ${LATEST_IIB_QUAY}"
    fi
    # shellcheck disable=SC2086
    if [[ $(skopeo --insecure-policy inspect docker://${LATEST_IIB_QUAY} 2>&1) == *"Error"* ]]; then
        echo "[ERROR] Cannot find image ${LATEST_IIB_QUAY} to copy!"
        echo "[ERROR] Check output of this command for an idea of what went wrong:"
        echo "[ERROR] ${buildCatalog} -t ${LATEST_IIB_QUAY}  --dir $CATALOG_DIR --ocp-ver $OCP_VER --push -v"
        exit 1
    fi

    # skopeo copy to additional tags
    ALL_TAGS="${DS_VERSION}-${OCP_VER}-$(uname -m)"
    for atag in $FLOATING_QUAY_TAGS; do
        ALL_TAGS="${ALL_TAGS} ${atag}-${OCP_VER}-$(uname -m)"
    done
    for atag in $EXTRA_TAGS; do
        ALL_TAGS="${ALL_TAGS} ${atag}-${OCP_VER}-$(uname -m)"
    done

    for qtag in ${ALL_TAGS}; do
        # shellcheck disable=SC2086
        if [[ $(skopeo --insecure-policy inspect docker://quay.io/devspaces/iib:${qtag} 2>&1) == *"Error"* ]] || [[ ${PUSHTOQUAYFORCE_LOCAL} -eq 1 ]]; then
            CMD="skopeo --insecure-policy copy --all docker://${LATEST_IIB_QUAY} docker://quay.io/devspaces/iib:${qtag}"
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
    # shellcheck disable=SC2086
    $PODMAN rmi --ignore --force ${LATEST_IIB} $targetIndexImage >/dev/null 2>&1 || true
done

# cleanup temp space
rm -fr /tmp/render-registry* /tmp/tmp.*
