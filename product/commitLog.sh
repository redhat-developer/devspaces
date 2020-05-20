#!/bin/bash -e
#
# Copyright (c) 2019-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to query the Brew BUILD ID for a given list of NVRs, then produce the list of SHAs associated with those builds
# requires brew CLI to be installed, and an active Kerberos ticket (kinit)

numCommits=5
user="$(whoami)" # default user to fetch sources from pkgs.devel repos
#jenkinsServer="https://$(host codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com | sed -e "s#.\+has address ##")" # or something else, https://crw-jenkins.redhat.com
jenkinsServer="https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com"
allNVRs=0
findLatest=0
generateDockerfileLABELs=0
LABELs=""
doClean=1

function usage () 
{
    echo "
Usage: ./${0##*/}

    --help          | show help

    -c numCommits   | limit query to only n commits (default: 5)
    -u user         | set kerberos username

    --list          | just list all available NVRs and exit - do not query commit logs
    -a              | query all NVRs
    NVR1 NVR2 ...   | query only specified NVRs, eg., codeready-workspaces-server-container-1.1-7
    -l, --latest    | check for the latest NVRs for the specified/partial NVRs, eg., 
                    |   codeready-workspaces-server-container, codeready-workspaces-server-container-1.1
    -g, --labels    | generate Dockerfile LABELs to commit into the repo; implies '-c 1 --latest'
    -nc, --noclean  | do not delete temp files when done (allows repeating the script more quickly)
    "
    exit 0
}

if [[ "$#" -eq 0 ]]; then usage; fi
while [[ "$#" -gt 0 ]]; do
  case $1 in
        # for any NVR (or partial NVR) compute the latest version; eg., for 
        # codeready-workspaces-server-container or codeready-workspaces-server-container-1.1 or codeready-workspaces-server-container-1.1-4,
        # use codeready-workspaces-server-container-1.1-7
    '-l'|'--latest') findLatest=1;; 
    '-g'|'--labels') generateDockerfileLABELs=1; findLatest=1; numCommits=1;; # implies that we only want to see the latest single commit
    '-c') numCommits="$2"; shift 1;; # eg., 5 or 10 commits to show
    '-u') user="$2"; shift 1;; # eg., $(whoami), nboldt or crw-build
    '-j') jenkinsServer="$2"; shift 1;; # to make URLs clickable in console, use a shorter URL like https://crw-jenkins.redhat.com
    '-a') allNVRs=1; shift 0;; # fetch all NVRs
    '-nc'|'--noclean') doClean=0;; 
    '--list') listNVRsOnly=1;;
    '--help') usage;;
    *) NVRs="${NVRs} $1"; shift 0;; 
  esac
  shift 1
done

if [[ ! ${WORKSPACE} ]]; then WORKSPACE=/tmp; fi

if [[ ! -x /usr/bin/brew ]]; then
    echo "Brew not install in /usr/bin/brew - please install it to continue."; exit 1
fi

# get latest NVRs if non specified
if [[ ! $NVRs ]] || [[ ${allNVRs} -eq 1 ]]; then
	echo -n "[INFO] Collect latest codeready-1.0-rhel-7-candidate and codeready-1.0-rhel-8-candidate containers..."
    NVRs=$(\
        brew list-tagged --latest codeready-1.0-rhel-7-candidate | grep -v apb | grep "codeready-workspaces" | \
            sed -e "s#[\ \t]\+codeready-1.0-rhel-7-candidate.\+##" && \
        brew list-tagged --latest codeready-1.0-rhel-8-candidate | egrep -v "java-container" | grep "codeready-workspaces" | \
            sed -e "s#[\ \t]\+codeready-1.0-rhel-8-candidate.\+##" \
    )
    echo "."
    for n in $NVRs; do
    	echo "       + $n"
    done
    echo ""
elif [[ ${findLatest} -eq 1 ]]; then
    inputNVRs="${NVRs}"; NVRs=""
    for n in $inputNVRs; do
        if [[ ${n%-container-*} != $n ]]; then 
            m="${n%-container-*}-container"
        elif [[ ${n} != *"-container" ]]; then
            m="${n}-container"
        else
            m="${n}"
        fi
        # debug
        # echo "       + $n ... $m"
        mm=$(brew list-tagged --latest codeready-1.0-rhel-7-candidate $m 2>&1 | grep $m | grep -v apb | grep "codeready-workspaces" | \
            sed -e "s#[\ \t]\+codeready-1.0-rhel-7-candidate.\+##")

        if [[ "${mm}" == "" ]]; then 
        # echo "check RHEL8..."
            mm=$(brew list-tagged --latest codeready-1.0-rhel-8-candidate $m 2>&1 | grep $m | egrep -v "java-container" | grep "codeready-workspaces" | \
                sed -e "s#[\ \t]\+codeready-1.0-rhel-8-candidate.\+##")
        fi
        if [[ "${mm}" == "" ]]; then 
            echo "[ERROR] Could not find $n in either of these requests: "
            echo "[ERROR] * \`brew list-tagged --latest codeready-1.0-rhel-7-candidate $m\`"
            echo "[ERROR] * \`brew list-tagged --latest codeready-1.0-rhel-7-candidate $m\`"
            exit;
        fi
        NVRs="${NVRs} $mm"
    done
fi

if [[ ${listNVRsOnly} -eq 1 ]]; then exit; fi

function addLabel () {
    addLabeln "${1}" "${2}" "${3}"
    echo ""
}
function addLabeln () {
    LABEL_VAR=$1
    if [[ "${2}" ]]; then LABEL_VAL=$2; else LABEL_VAL="${!LABEL_VAR}"; fi
    if [[ "${3}" ]]; then PREFIX=$3; else PREFIX="  << "; fi
    if [[ ${generateDockerfileLABELs} -eq 1 ]]; then 
        LABELs="${LABELs} ${LABEL_VAR}=\"${LABEL_VAL}\""
    fi
    echo -n "${PREFIX}${LABEL_VAL}"
}

function parseCommitLog () 
{
    # Update from Jenkins ::
    # crw_master ::
    # Build #246 (2019-02-26 04:23:36 EST) ::
    # che @ f34f4c6c82de35081351e0b0686b1ae6589735d4 (6.19.0-SNAPSHOT) ::
    # codeready-workspaces @ 184e24bee5bd923b733fa8c9f4b055a9caad40d2 (1.1.0.GA) ::
    # codeready-workspaces-deprecated @ 620a53c5b0a1bbc02ba68e96be94ec3b932c9bee (1.0.0.GA-SNAPSHOT) ::
    # codeready-workspaces-assembly-main.tar.gz
    # codeready-workspaces-stacks-language-servers-dependencies-bayesian.tar.gz
    # codeready-workspaces-stacks-language-servers-dependencies-node.tar.gz
    tarballs=""
    OTHER=""
    JOB_NAME=""
    GHE="https://github.com/eclipse/"
    GHR="https://github.com/redhat-developer/"
    while [[ "$#" -gt 0 ]]; do
      case $1 in
        'crw_master'|'crw_stable-branch'|'crw-operator-installer-and-ls-deps_'*) JOB_NAME="$1"; shift 2;;
        'Build'*) BUILD_NUMBER="$2"; BUILD_NUMBER=${BUILD_NUMBER#\#}; shift 6;; # trim # from the number, ignore timestamp
        'che-dev'|'che-parent'|'che-lib'|'che') 
            sha="$3"; addLabeln "git.commit.eclipse__${1}" "${GHE}${1}/commit/${sha:0:7}"; addLabel "pom.version.eclipse__${1}" "${4:1:-1}" " "; shift 5;;
        'codeready-workspaces'|'codeready-workspaces-deprecated') 
            sha="$3"; addLabeln "git.commit.redhat-developer__${1}" "${GHR}${1}/commit/${sha:0:7}"; addLabel "pom.version.redhat-developer__${1}" "${4:1:-1}" " "; shift 5;;
        *'tar.gz') tarballs="${tarballs} $1"; shift 1;;
        *) OTHER="${OTHER} $1"; shift 1;; 
      esac
    done
    if [[ $JOB_NAME ]]; then
        addLabel "jenkins.build.url" "${jenkinsServer}/view/CRW_CI/view/Pipelines/job/${JOB_NAME}/${BUILD_NUMBER}/"
        for t in $tarballs; do
            addLabel "jenkins.artifact.url" "${jenkinsServer}/view/CRW_CI/view/Pipelines/job/${JOB_NAME}/${BUILD_NUMBER}/artifact/**/${t}" "     ++ "
        done
    else
        addLabel "jenkins.tarball.url" "${jenkinsServer}/view/CRW_CI/view/Pipelines #${BUILD_NUMBER} /${tarballs}"
    fi
}

function insertLabels () {
    DOCKERFILE=$1
    # trim off the footer of the file
    mv ${DOCKERFILE} ${DOCKERFILE}.bak
    sed '/.*insert generated LABELs below this line.*/q' ${DOCKERFILE}.bak > ${DOCKERFILE}
    # insert marker
    if [[ ! $(cat ${DOCKERFILE}.bak | grep "insert generated LABELs below this line") ]]; then 
        echo "" >> ${DOCKERFILE}
        echo "" >> ${DOCKERFILE}
        echo "# insert generated LABELs below this line" >> ${DOCKERFILE}
    fi
    # add new labels
    echo "LABEL \\" >> ${DOCKERFILE}
    for l in $LABELs; do
        echo "      ${l} \\" >> ${DOCKERFILE}
    done
    echo "" >> ${DOCKERFILE}
    rm -f ${DOCKERFILE}.bak
}

cd ${WORKSPACE}
for n in $NVRs; do
    LABELs=""
    echo ""
    # use brew buildinfo to get the repo and sha used to build a given NVR
    repo=$(brew buildinfo $n | grep "Source:" | sed -e "s#Source: git://##")
    sha=${repo#*#}; sha=${sha:0:7} # echo $sha
    repo=${repo%#*}; # echo $repo

    if [[ ! $repo ]]; then
        echo "[ERROR] Brew build not found for $n"; exit 1
    fi

    # fetch sources so we can see the log
    if [[ ! -d ${n}_sources ]]; then 
        echo -n "[INFO] git clone ssh://${user}@${repo} ${n}_sources ..."
        git clone ssh://${user}@${repo} ${n}_sources -q
        echo "."
    fi
    cd ${WORKSPACE}/${n}_sources
        git fetch
        git checkout $sha -q
        echo "== $repo @ $sha / ${n} =="; echo ""
        git --no-pager log --pretty=format:'%h - %s'  -${numCommits} > $WORKSPACE/${n}_log.txt
        # add newline so that the last commit in the file is picked up
        echo "" >> $WORKSPACE/${n}_log.txt 

        while read l; do
            c_sha=${l:0:7}; # echo $c_sha
            echo -n "https://${repo/\///cgit/}/commit/?id=${c_sha}"
            echo " ${l#${c_sha} }"
            if [[ "$l" == *" [sync] Update from "*" @ "* ]]; then
                # https://github.com/eclipse/che-operator/commit/9ce11db452b4f62a730311b4108fe9ca6bc0b577
                # https://pkgs.devel.redhat.com/cgit/containers/codeready-workspaces/commit/?id=8a13c2ce4dfdbae7c0ac29198339cc39b6881798
                lrepo=${l##*Update from }; lrepo=${lrepo%% @ *}; # echo "   >> lrepo = https://github.com/$lrepo"
                lsha=${l##* @ }
                addLabel "git.commit.${lrepo/\//__}" "https://github.com/${lrepo}/commit/${lsha}"
            elif [[ "$l" == *" [base] "?"pdate from "*" to "* ]] || [[ "$l" == *" [update base] "?"pdate from "*" to "* ]] || \
                 [[ "$l" == *" [updateDockerfilesFROM.sh] "?"pdate from "*" to "* ]]; then
                # https://access.redhat.com/containers/#/registry.access.redhat.com/rhel7/images/7.6-151.1550575774
                loldbase=${l##*pdate from };loldbase=${loldbase%% to *}; loldbase=${loldbase/://images/}
                lnewbase=${l##* to };lnewbase=${lnewbase/://images/}
                addLabel "container.base.old" "https://access.redhat.com/containers/#/registry.access.redhat.com/${loldbase}"
                addLabel "container.base.new" "https://access.redhat.com/containers/#/registry.access.redhat.com/${lnewbase}" "  >> "
            elif [[ "$l" == *" [get sources] "?"pdate from "* ]]; then
                parseCommitLog ${l##*\[get sources\]}
            fi
            # echo "  == https://${repo/\///cgit/}/commit/?id=${c_sha}"
            echo ""
        done < $WORKSPACE/${n}_log.txt

        if [[ ${generateDockerfileLABELs} -eq 1 ]] && [[ "${LABELs}" ]]; then
            echo "[INFO] The following LABELs will be committed to the repo:"
            for l in $LABELs; do echo " + LABEL ${l}"; done

            git fetch
            git_branch=codeready-1.0-rhel-7
            if [[ "${n}" == *"rhel8"* ]]; then
                git_branch=codeready-1.0-rhel-8
                if [[ "$(git checkout ${git_branch} 2>&1)" == *"error"* ]]; then
                    echo "Could not check out the ${git_branch} branch!"
                    exit 1
                fi
            else
                git checkout ${git_branch}
            fi
            git pull origin ${git_branch}
            insertLabels $WORKSPACE/${n}_sources/Dockerfile
            git commit -s -m "[labels] Update generated LABELs in Dockerfile" Dockerfile
            git push origin ${git_branch}

            # if this is called from within the sync job for codeready-workspaces GH repo -> pkgs.devel server, push this change to upstream too
            if [[ -f $WORKSPACE/sources/Dockerfile ]]; then
                pushd $WORKSPACE/sources >/dev/null
                insertLabels $WORKSPACE/sources/Dockerfile
                git commit -s -m "[labels] Update generated LABELs in Dockerfile" Dockerfile
                git push
                popd >/dev/null
            fi
        fi
    cd ..
    #cleanup temp files
    if [[ ${doClean} -eq 1 ]]; then
      rm -fr ${WORKSPACE}/${n}*
    fi
done
