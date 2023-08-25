#!/bin/bash
#
# Copyright (c) 2021-2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
# script to convert previously downloaded dist-git lookaside cached tarballs into format compatible with Legal requirements (NVR.tar.gz)

set -e

# today's date in yyyy-mm-dd format to use to ensure each GA push is a unique folder
today=$(date +%Y-%m-%d)

MIDSTM_BRANCH=""
CSV_VERSION=""
pduser="devspaces-build"
DEBUG=0
CLEAN=1 # by default delete intermediate assets to save disk space
phases=" 1 2 3 "
PUBLISH=0 # by default don't publish sources to spmm-util
REMOTE_USER_AND_HOST="devspaces-build@spmm-util.engineering.redhat.com"

usage () 
{
    echo "Usage: $0 -b devspaces-3.y-rhel-8 [--clean] [--debug] -[w WORKSPACE_DIR]

Options:
    --publish                             publish GA bits for a release to $REMOTE_USER_AND_HOST
    --desthost user@destination-host      specific an alternate destination host for publishing
"
    exit
}

# a more extensive clean than the usual
cleanup () {
    sudo rm -fr "${WORKSPACE}"/NVR_CHECKOUTS
    sudo rm -f "${WORKSPACE}"/NVRs.txt
}

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-pduser') pduser="$2"; shift 1;;
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    '-v') CSV_VERSION="$2"; shift 1;; # 3.y.0
    '--publish') PUBLISH=1;;
    '--desthost') REMOTE_USER_AND_HOST="$2"; shift 1;;
    '--keep-temp') CLEAN=0;;
    '--clean') cleanup;;
    '--debug') DEBUG=1;;
    '-w') WORKSPACE="$2"; shift 1;;
    *) phases="${phases} $1 ";;
  esac
  shift 1
done

if [[ ! "${MIDSTM_BRANCH}" ]]; then usage; fi
if [[ ! ${phases} ]]; then phases=" 1 2 3 "; fi
if [[ ! "${WORKSPACE}" ]]; then WORKSPACE=/tmp; fi
if [[ ! "$CSV_VERSION" ]]; then CSV_VERSION=$(curl -sSLo- "https://raw.githubusercontent.com/redhat-developer/devspaces-images/${MIDSTM_BRANCH}/devspaces-operator-bundle/manifests/devspaces.csv.yaml" | yq -r '.spec.version'); fi

TARBALL_PREFIX="devspaces-${CSV_VERSION}"
TODAY_DIR="${WORKSPACE}/${TARBALL_PREFIX}.${today}"

MANIFEST_FILE="${TODAY_DIR}"/sources/manifest-srcs.txt

sudo rm -fr "${MANIFEST_FILE}" "${WORKSPACE}"/nvr-sources/ "${TODAY_DIR}"/sources/containers/ "${TODAY_DIR}"/sources/vscode/

mkdir -p "${TODAY_DIR}"/sources/

mnf () {
    echo "$1" | tee -a "${MANIFEST_FILE}"
}

maketarball () 
{
    SOURCES_DIR=$1
    NVR=$2

    echo "Make tarball from $SOURCES_DIR"
    pushd "$SOURCES_DIR" >/dev/null 

    # update to latest
    git clean -f || true
    git checkout "${MIDSTM_BRANCH}" -q || true
    git pull origin "${MIDSTM_BRANCH}" -q || true

    # pull tarballs, but only if there's a sources and .spec file
    if [[ -f sources ]] && [[ -f sources.spec ]]; then rhpkg sources; fi

    # unpack 3rd party dep tarballs
    # shellcheck disable=SC2044
    for t in $(find . -name "*.tar.gz" -o -name "*.tgz"); do
        subfolder=${t//.\/devspaces-/}
        subfolder=${subfolder//asset-/}
        subfolder=${subfolder//.tar.gz/}
        subfolder=${subfolder//.tgz/}
        mkdir -p "${WORKSPACE}"/nvr-sources/"${NVR}"/"${subfolder}"
        mnf "Unpack $(pwd)/${t//\.\//} to ${WORKSPACE}/nvr-sources/${NVR}/${subfolder}"
        tar xzf "$t" -C "${WORKSPACE}"/nvr-sources/"${NVR}"/"${subfolder}"
    done

    # add in pkgs.devel sources
    SRC_DIR_IN_TARBALL="$(git remote -v | grep origin | grep pkgs | grep fetch | sed -e "s#.\+\(pkgs.devel.\+\) .\+#\1#")"
    mkdir -p "${WORKSPACE}"/nvr-sources/"${NVR}"/"${SRC_DIR_IN_TARBALL}"/
    pushd .. >/dev/null 
        rsync -arz "${SOURCES_DIR}" "${WORKSPACE}"/nvr-sources/"${NVR}"/"${SRC_DIR_IN_TARBALL}"/ --exclude=".git" --exclude="*.tar.gz" --exclude="*.tgz"
    popd >/dev/null 

    if [[ -d "${WORKSPACE}"/nvr-sources/"${NVR}" ]]; then
        mnf "Create ${WORKSPACE}/sources/containers/${NVR}.tar.gz"
        mkdir -p "${TODAY_DIR}"/sources/containers/
        pushd "${WORKSPACE}"/nvr-sources/"${NVR}" >/dev/null && tar czf "${TODAY_DIR}"/sources/containers/"${NVR}".tar.gz ./* && popd >/dev/null 
        mnf "" 
        if [[ $CLEAN -eq 1 ]]; then df -h "${WORKSPACE}"; sudo rm -fr "${WORKSPACE}"/nvr-sources/"${NVR}"; df -h "${WORKSPACE}"; fi

    fi
    popd >/dev/null 
}

##################################
# PHASE 1 - get pkgs.devel sources, including rhpkg sources (binaries)
##################################

if [[ ${phases} == *"1"* ]]; then
    mnf ""
    mnf "Phase 1 - get pkgs.devel sources, including rhpkg sources (binaries)"
    mnf ""

    # check NVR for a matching tarball or tarballs
    if [[ ! -f "${WORKSPACE}"/NVRs.txt ]]; then
        mnf "Latest image list for branch ${MIDSTM_BRANCH}"
        ../getLatestImageTags.sh -b "${MIDSTM_BRANCH}" --nvr | tee "${WORKSPACE}"/NVRs.txt
        mnf ""
    fi

    mkdir -p "${WORKSPACE}"/NVR_CHECKOUTS
    pushd "${WORKSPACE}"/NVR_CHECKOUTS >/dev/null
        # shellcheck disable=SC2013
        for d in $(sort "${WORKSPACE}"/NVRs.txt); do
            NVR=${d}
            SOURCES_DIR=${d%-container-*}; SOURCES_DIR=${SOURCES_DIR/-rhel8}; # echo $SOURCES_DIR
            echo "git clone --depth 1 --branch ${MIDSTM_BRANCH} to ${SOURCES_DIR} ..."
            git clone --depth 1 --branch "${MIDSTM_BRANCH}" "ssh://${pduser}@pkgs.devel.redhat.com/containers/${SOURCES_DIR}" "${SOURCES_DIR}" || true
            cd "${SOURCES_DIR}" && git checkout "${MIDSTM_BRANCH}" -q && cd ..
            if [[ -d "${SOURCES_DIR}" ]]; then
                maketarball "${SOURCES_DIR}" "${NVR}"
                if [[ $CLEAN -eq 1 ]]; then df -h "${WORKSPACE}"; sudo rm -fr "${WORKSPACE}"/NVR_CHECKOUTS/"${SOURCES_DIR}"; df -h "${WORKSPACE}"; fi
            else
                echo "FAIL! could not find sources in ${SOURCES_DIR}!"
                exit 1
            fi
        done
    popd >/dev/null
fi

##################################
# PHASE 2 - get vsix sources not included in rhpkg sources
##################################

if [[ ${phases} == *"2"* ]]; then
    mnf ""
    mnf "Phase 2 - get vsix sources not included in rhpkg sources from GH"
    mnf ""
    mkdir -p "${TODAY_DIR}"/sources/vscode/
    pushd ../../dependencies/che-plugin-registry >/dev/null
        URLsAll=""
        URLs=""
        for d in $(find . -name \*.yaml | sort); do 
            URLsAll="${URLsAll} $(grep -E "\.vsix" "$d" | grep github | grep releases | sed -r -e "s@- @@" -e "s@extension: @@" | tr -d "'\"")"
        done
        if [[ $URLsAll ]]; then
            for u in $URLsAll; do 
                if [[ ${URLs} != *"${u}"* ]]; then URLs="${URLs} ${u}"; fi # only add if new
            done
            # shellcheck disable=SC2086
            for u in $(echo $URLs | sort | uniq); do
                if [[ ${DEBUG} -eq 1 ]]; then 
                    echo
                    echo -n "Fetch GH sources for  "
                    mnf $u
                fi
                # shellcheck disable=SC2086 disable=SC2001
                s=$(echo $u | sed -e "s@\(.\+\)/releases/download/\(.\+\)/\(.\+\)@\1/archive/\2.tar.gz@"); # echo "-> $s"
                f=${s#https://}; f=${f//\//__}; # echo "-> $f"
                echo -n "Fetch GH sources from "
                mnf $s
                curl -sSL $s -o "${TODAY_DIR}"/sources/vscode/$f
            done
        fi
    popd >/dev/null
fi

if [[ ${phases} == *"3"* ]]; then
    mnf ""
    mnf "Phase 3 - get vsix sources not included in rhpkg sources from download.jboss.org (or github)"
    mnf ""
    mkdir -p "${TODAY_DIR}"/sources/vscode/
    pushd ../../dependencies/che-plugin-registry >/dev/null
        URLsAll=""
        URLs=""
        for d in $(find . -name meta.yaml | sort); do 
            URLsAll="${URLsAll} $(grep -E "\.vsix" "$d" | grep download.jboss.org | sed -e "s@- @@" | sort -V)"
        done
        if [[ $URLsAll ]]; then
            for u in $URLsAll; do 
                if [[ ${URLs} != *"${u}"* ]]; then URLs="${URLs} ${u}"; fi # only add if new
            done
            # shellcheck disable=SC2086
            for u in $(echo $URLs | sort | uniq); do
                d=${u%/*}/ # echo $d
                version=${u##*/}; version=$(echo $version | sed -r -e "s#.+[a-z]+-([0-9-]+.*).vsix#\1#"); # echo $version
                versionSHA=${version##*-}; # echo $versionSHA
                # shellcheck disable=SC2295
                version=${version%-${versionSHA}}
                if [[ ${DEBUG} -eq 1 ]]; then 
                    echo
                    if [[ "${version}" != "${versionSHA}" ]]; then
                        echo "Check dl.jb.o sources ${d} for ${version} or ${versionSHA}"
                    else
                        echo "Check dl.jb.o sources ${d} for ${version}"
                    fi
                fi
                f=${u#https://}; f=${f//\//__}; # echo "-> $f"
                mkdir -p "${TODAY_DIR}"/sources/vscode/$f
                pushd "${TODAY_DIR}"/sources/vscode/$f >/dev/null
                    # different patterns for source tarballs
                    if [[ ${f} == *"static__jdt.ls__stable"* ]]; then # get from GH
                        # check https://github.com/redhat-developer/vscode-java/archive/v0.57.0.tar.gz
                        z="https://github.com/redhat-developer/vscode-java/archive/v${version}.tar.gz"
                        echo -n "Fetch GH sources from "
                        mnf ${z}
                        curl -sSLO ${z}
                    else # get from dl.jb.o
                        wget ${d} -r -l 1 -w 2 --no-parent --no-directories --no-host-directories -q
                        # shellcheck disable=SC2013
                        for z in $(grep gz index.html | grep -v "sha256" | sed -r -e 's#.+href="([^"]+)".+#\1#g'); do
                            # shellcheck disable=SC2143
                            if [[ $(echo ${z} | grep -E "${version}|${versionSHA}-sources") ]]; then
                                echo -n "Fetch dl.jb.o sources "
                                mnf ${d}${z}
                                curl -sSLO ${d}${z}
                            else
                                if [[ ${DEBUG} -eq 1 ]]; then 
                                    if [[ "${version}" != "${versionSHA}" ]]; then
                                        echo "              Skip ${z} - no match for ${version} or ${versionSHA}"
                                    else
                                        echo "              Skip ${z} - no match for ${version}"
                                    fi
                                fi
                            fi
                        done
                    fi
                    sudo rm -f index.html robots.txt
                popd >/dev/null
            done
        fi
    popd >/dev/null
fi

du -shc "${TODAY_DIR}"/sources/containers/* "${TODAY_DIR}"/sources/vscode/* || true

##################################

echo ""
echo "Short MVN manifest is in file: ${MANIFEST_FILE}"
echo "NVR Source tarballs are in ${TODAY_DIR}/sources/containers/ and ${TODAY_DIR}/sources/vscode/"
echo ""

##################################

# optionally, push files to spmm-util server as part of a GA release
if [[ $PUBLISH -eq 1 ]]; then
    set -x
    # create an empty dir into which we will make subfolders
    empty_dir=$(mktemp -d)

    # delete old releases before pushing latest one, to keep disk usage low: DO NOT delete 'CI' or 'build-requirements' folders as we use them
    # for storing CI builds and binaries we can't yet build ourselves in OSBS
    # note that this operation will only REMOVE old versions
    rsync -rlP --delete --exclude=CI --exclude=build-requirements --exclude="${TARBALL_PREFIX}.${today}" "$empty_dir"/ "${REMOTE_USER_AND_HOST}:staging/devspaces/"

    # next, update existing ${TARBALL_PREFIX}.${today} folder (or create it not exist)
    rsync -rlP "${TODAY_DIR}" "${REMOTE_USER_AND_HOST}:staging/devspaces/"

    # trigger staging 
    ssh "${REMOTE_USER_AND_HOST}" "stage-mw-release ${TARBALL_PREFIX}.${today}"

    # cleanup 
    rm -fr "$empty_dir"
    set +x
fi
