#!/bin/bash

# script to convert previously downloaded dist-git lookaside cached tarballs into format compatible with Legal requirements (NVR.tar.gz)

# TODO: make this script ALSO fetch the tarballs from Jenkins so we can do historical sources

CRW_BRANCH=crw-2.0-rhel-8
DEBUG=0
phases=""

cd /tmp
MANIFEST_FILE=/tmp/manifest-srcs.txt

# a more extensive clean than the usual
cleanup () {
    sudo rm -fr /tmp/NVR_CHECKOUTS
    rm -f /tmp/NVRs.txt
}

# commandline args
for key in "$@"; do
  case $key in
    '--clean') cleanup;;
    '--debug') DEBUG=1;;
    *) phases="${phases} $1 ";;
  esac
  shift 1
done

if [[ ! ${phases} ]]; then phases=" 1 2 3 "; fi

sudo rm -fr ${MANIFEST_FILE} /tmp/nvr-sources/ /tmp/NVR_SOURCES/ /tmp/VSIX_SOURCES/

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
        mkdir -p /tmp/nvr-sources/${NVR}/${subfolder}
        mnf "Unpack $(pwd)/${t//\.\//} to /tmp/nvr-sources/${NVR}/${subfolder}"
        tar xzf $t -C /tmp/nvr-sources/${NVR}/${subfolder}
    done

    # add in pkgs.devel sources
    SRC_DIR_IN_TARBALL="$(git remote -v | grep origin | grep pkgs | grep fetch | sed -e "s#.\+\(pkgs.devel.\+\) .\+#\1#")"
    mkdir -p /tmp/nvr-sources/${NVR}/${SRC_DIR_IN_TARBALL}/
    pushd .. >/dev/null 
        rsync -arz ${SOURCES_DIR} /tmp/nvr-sources/${NVR}/${SRC_DIR_IN_TARBALL}/ --exclude=".git" --exclude="*.tar.gz" --exclude="*.tgz"
    popd >/dev/null 

    if [[ -d /tmp/nvr-sources/${NVR} ]]; then
        mnf "Create /tmp/NVR_SOURCES/${NVR}.tar.gz"
        mkdir -p /tmp/NVR_SOURCES/
        pushd /tmp/nvr-sources/${NVR} >/dev/null && tar czf /tmp/NVR_SOURCES/${NVR}.tar.gz ./* && popd >/dev/null 
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
    if [[ ! -f /tmp/NVRs.txt ]]; then
        ${HOME}/51/codeready-workspaces/product/getLatestImageTags.sh \
            --crw21 --nvr | tee /tmp/NVRs.txt
    fi
    cat /tmp/NVRs.txt | sort | tee -a ${MANIFEST_FILE}
    mnf ""

    mkdir -p /tmp/NVR_CHECKOUTS
    pushd /tmp/NVR_CHECKOUTS >/dev/null
        for d in $(cat /tmp/NVRs.txt | sort); do
            NVR=${d}
            SOURCES_DIR=${d%-container-*}; SOURCES_DIR=${SOURCES_DIR/-rhel8}; SOURCES_DIR=${SOURCES_DIR/-server}; # echo $SOURCES_DIR
            echo "git clone ${SOURCES_DIR} from ${CRW_BRANCH} ..."
            git clone -q ssh://nboldt@pkgs.devel.redhat.com/containers/${SOURCES_DIR} ${SOURCES_DIR} || true
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
    mkdir -p /tmp/VSIX_SOURCES/
    pushd ${HOME}/51/codeready-workspaces/dependencies/che-plugin-registry >/dev/null
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
                curl -sSL $s -o /tmp/VSIX_SOURCES/$f
            done
        fi
    popd >/dev/null
fi

if [[ ${phases} == *"3"* ]]; then
    mnf ""
    mnf "Phase 3 - get vsix sources not included in rhpkg sources from download.jboss.org (or github)"
    mnf ""
    mkdir -p /tmp/VSIX_SOURCES/
    pushd ${HOME}/51/codeready-workspaces/dependencies/che-plugin-registry >/dev/null
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
                mkdir -p /tmp/VSIX_SOURCES/$f
                pushd /tmp/VSIX_SOURCES/$f >/dev/null
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

##################################

echo ""
echo "Short MVN manifest is in file: ${MANIFEST_FILE}"
echo "NVR Source tarballs are in /tmp/NVR_SOURCES/ and /tmp/VSIX_SOURCES/"
echo ""

##################################
