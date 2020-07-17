#!/bin/bash
set +x
set -e

# script to convert previously downloaded dist-git lookaside cached tarballs into format compatible with Legal requirements (NVR.tar.gz)

# TODO: make this script ALSO fetch the tarballs from Jenkins so we can do historical sources

getLatestImageTagsFlags="" # placeholder for a --crw22 flag to pass to getLatestImageTags.sh
CRW_BRANCH="crw-2.2-rhel-8"
PKGS_DEVEL_USER="crw-build"
DEBUG=0
phases=" 1 2 3 "

# a more extensive clean than the usual
cleanup () {
    sudo rm -fr ${WORKSPACE}/NVR_CHECKOUTS
    rm -f ${WORKSPACE}/NVRs.txt
}

# commandline args
for key in "$@"; do
  case $key in
    '--clean') cleanup;;
    '--debug') DEBUG=1;;
    '--crw'*) getLatestImageTagsFlags="$1";;
    *) phases="${phases} $1 ";;
  esac
  shift 1
done
if [[ ! ${phases} ]]; then phases=" 1 2 3 "; fi
if [[ ! ${WORKSPACE} ]]; then WORKSPACE=/tmp; fi

MANIFEST_FILE=${WORKSPACE}/manifest-srcs.txt

sudo rm -fr ${MANIFEST_FILE} ${WORKSPACE}/nvr-sources/ ${WORKSPACE}/sources/containers/ ${WORKSPACE}/sources/vscode/

mnf () {
    echo "$1" | tee -a ${MANIFEST_FILE}
}

#TODO for historical builds, must query old dockerfiles for the version of tarball used and pull older sources (or regen them)

maketarball () 
{
    SOURCES_DIR=$1
    NVR=$2

    echo "Make tarball from $SOURCES_DIR"
    pushd $SOURCES_DIR >/dev/null 

    # update to latest
    # git clean -f
    # git checkout ${CRW_BRANCH} -q
    git pull origin ${CRW_BRANCH} -q

    # pull tarballs
    rhpkg sources

    # unpack 3rd party dep tarballs
    for t in $(find . -name "*.tar.gz" -o -name "*.tgz"); do
        subfolder=${t//.\/codeready-workspaces-/}
        subfolder=${subfolder//stacks-language-servers-dependencies-/}
        subfolder=${subfolder//.tar.gz/}
        subfolder=${subfolder//.tgz/}
        mkdir -p ${WORKSPACE}/nvr-sources/${NVR}/${subfolder}
        mnf "Unpack $(pwd)/${t//\.\//} to ${WORKSPACE}/nvr-sources/${NVR}/${subfolder}"
        tar xzf $t -C ${WORKSPACE}/nvr-sources/${NVR}/${subfolder}
    done

    # add in pkgs.devel sources
    SRC_DIR_IN_TARBALL="$(git remote -v | grep origin | grep pkgs | grep fetch | sed -e "s#.\+\(pkgs.devel.\+\) .\+#\1#")"
    mkdir -p ${WORKSPACE}/nvr-sources/${NVR}/${SRC_DIR_IN_TARBALL}/
    pushd .. >/dev/null 
        rsync -arz ${SOURCES_DIR} ${WORKSPACE}/nvr-sources/${NVR}/${SRC_DIR_IN_TARBALL}/ --exclude=".git" --exclude="*.tar.gz" --exclude="*.tgz"
    popd >/dev/null 

    if [[ -d ${WORKSPACE}/nvr-sources/${NVR} ]]; then
        mnf "Create ${WORKSPACE}/sources/containers/${NVR}.tar.gz"
        mkdir -p ${WORKSPACE}/sources/containers/
        pushd ${WORKSPACE}/nvr-sources/${NVR} >/dev/null && tar czf ${WORKSPACE}/sources/containers/${NVR}.tar.gz ./* && popd >/dev/null 
        mnf "" 
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
    if [[ ! -f ${WORKSPACE}/NVRs.txt ]]; then
        mnf "Latest image list ${getLatestImageTagsFlags}"
        ../getLatestImageTags.sh ${getLatestImageTagsFlags} --nvr | tee ${WORKSPACE}/NVRs.txt
        mnf ""
    fi
    mnf "Sorted image list"
    cat ${WORKSPACE}/NVRs.txt | sort | tee -a ${MANIFEST_FILE}
    mnf ""

    mkdir -p ${WORKSPACE}/NVR_CHECKOUTS
    pushd ${WORKSPACE}/NVR_CHECKOUTS >/dev/null
        for d in $(cat ${WORKSPACE}/NVRs.txt | sort); do
            NVR=${d}
            SOURCES_DIR=${d%-container-*}; SOURCES_DIR=${SOURCES_DIR/-rhel8}; SOURCES_DIR=${SOURCES_DIR/-server}; # echo $SOURCES_DIR
            echo "git clone ${SOURCES_DIR} from ${CRW_BRANCH} ..."
            git clone -q ssh://${PKGS_DEVEL_USER}@pkgs.devel.redhat.com/containers/${SOURCES_DIR} ${SOURCES_DIR} || true
            cd ${SOURCES_DIR} && git checkout ${CRW_BRANCH} -q && cd ..
            if [[ -d ${SOURCES_DIR} ]]; then
                maketarball ${SOURCES_DIR} ${NVR}
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
    mkdir -p ${WORKSPACE}/sources/vscode/
    pushd ../../dependencies/che-plugin-registry >/dev/null
        URLsAll=""
        URLs=""
        for d in $(find . -name meta.yaml | sort); do 
            URLsAll="${URLsAll} $(cat $d | egrep "\.vsix|\.theia" | grep github | grep releases | sed -e "s@- @@")"
        done
        if [[ $URLsAll ]]; then
            for u in $URLsAll; do 
                if [[ ${URLs} != *"${u}"* ]]; then URLs="${URLs} ${u}"; fi # only add if new
            done
            for u in $(echo $URLs | sort | uniq); do
                if [[ ${DEBUG} -eq 1 ]]; then 
                    echo
                    echo -n "Fetch GH sources for  "
                    mnf $u
                fi
                s=$(echo $u | sed -e "s@\(.\+\)/releases/download/\(.\+\)/\(.\+\)@\1/archive/\2.tar.gz@"); # echo "-> $s"
                f=${s#https://}; f=${f//\//__}; # echo "-> $f"
                echo -n "Fetch GH sources from "
                mnf $s
                curl -sSL $s -o ${WORKSPACE}/sources/vscode/$f
            done
        fi
    popd >/dev/null
fi

if [[ ${phases} == *"3"* ]]; then
    mnf ""
    mnf "Phase 3 - get vsix sources not included in rhpkg sources from download.jboss.org (or github)"
    mnf ""
    mkdir -p ${WORKSPACE}/sources/vscode/
    pushd ../../dependencies/che-plugin-registry >/dev/null
        URLsAll=""
        URLs=""
        for d in $(find . -name meta.yaml | sort); do 
            URLsAll="${URLsAll} $(cat $d | egrep "\.vsix|\.theia" | grep download.jboss.org | sed -e "s@- @@" | sort -V)"
        done
        if [[ $URLsAll ]]; then
            for u in $URLsAll; do 
                if [[ ${URLs} != *"${u}"* ]]; then URLs="${URLs} ${u}"; fi # only add if new
            done
            for u in $(echo $URLs | sort | uniq); do
                d=${u%/*}/ # echo $d
                version=${u##*/}; version=$(echo $version | sed -r -e "s#.+[a-z]+-([0-9-]+.*).vsix#\1#"); # echo $version
                versionSHA=${version##*-}; # echo $versionSHA
                version=${version%-${versionSHA}}
                if [[ ${DEBUG} -eq 1 ]]; then 
                    echo
                    if [[ ${version} != ${versionSHA} ]]; then
                        echo "Check dl.jb.o sources ${d} for ${version} or ${versionSHA}"
                    else
                        echo "Check dl.jb.o sources ${d} for ${version}"
                    fi
                fi
                f=${u#https://}; f=${f//\//__}; # echo "-> $f"
                mkdir -p ${WORKSPACE}/sources/vscode/$f
                pushd ${WORKSPACE}/sources/vscode/$f >/dev/null
                    # different patterns for source tarballs
                    if [[ ${f} == *"static__jdt.ls__stable"* ]]; then # get from GH
                        # check https://github.com/redhat-developer/vscode-java/archive/v0.57.0.tar.gz
                        z="https://github.com/redhat-developer/vscode-java/archive/v${version}.tar.gz"
                        echo -n "Fetch GH sources from "
                        mnf ${z}
                        curl -sSLO ${z}
                    else # get from dl.jb.o
                        wget ${d} -r -l 1 -w 2 --no-parent --no-directories --no-host-directories -q
                        for z in $(cat index.html | grep gz | grep -v "sha256" | sed -r -e 's#.+href="([^"]+)".+#\1#g'); do
                            if [[ $(echo ${z} | egrep "${version}|${versionSHA}-sources") ]]; then
                                echo -n "Fetch dl.jb.o sources "
                                mnf ${d}${z}
                                curl -sSLO ${d}${z}
                            else
                                if [[ ${DEBUG} -eq 1 ]]; then 
                                    if [[ ${version} != ${versionSHA} ]]; then
                                        echo "              Skip ${z} - no match for ${version} or ${versionSHA}"
                                    else
                                        echo "              Skip ${z} - no match for ${version}"
                                    fi
                                fi
                            fi
                        done
                    fi
                    rm -f index.html robots.txt
                popd >/dev/null
            done
        fi
    popd >/dev/null
fi

du -shc ${WORKSPACE}/sources/containers/* ${WORKSPACE}/sources/vscode/*

##################################

echo ""
echo "Short MVN manifest is in file: ${MANIFEST_FILE}"
echo "NVR Source tarballs are in ${WORKSPACE}/sources/containers/ and ${WORKSPACE}/sources/vscode/"
echo ""

##################################
