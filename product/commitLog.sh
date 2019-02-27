#!/bin/bash -e
#
# script to query the Brew BUILD ID for a given list of NVRs, then produce the list of SHAs associated with those builds
# requires brew CLI to be installed, and an active Kerberos ticket (kinit)

#WORKDIR=`pwd` # NOT USED
#BRANCH=codeready-1.0-rhel-7 # not master # NOT USED

numCommits=10
user="$(whoami)" # default user to fetch sources from pkgs.devel repos
jenkinsServer="https://$(host codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com | sed -e "s#.\+has address ##")" # or something else, https://crw-jenkins.redhat.com
htmlMode=0 # TODO implement this

while [[ "$#" -gt 0 ]]; do
  case $1 in
    #'-w') WORKDIR="$2"; shift 1;; # NOT USED
    #'-b') BRANCH="$2"; shift 1;; # NOT USED 
    '-c') numCommits="$2"; shift 1;; # eg., 5 or 10 commits to show
    '-n') NVRs="$2"; shift 1;; # eg., codeready-workspaces-server-container-1.1-2
    '-u') user="$2"; shift 1;; # eg., $(whoami), nboldt or crw-build
    '-j') jenkinsServer="$2"; shift 1;; # to make URLs clickable in console, use a shorter URL like https://crw-jenkins.redhat.com
    '--html') htmlMode=1; shift 0;; # TODO implement this
    *) OTHER="${OTHER} $1"; shift 0;; 
  esac
  shift 1
done

if [[ ! ${WORKSPACE} ]]; then WORKSPACE=/tmp; fi

if [[ ! -x /usr/bin/brew ]]; then
    echo "Brew not install in /usr/bin/brew - please install it to continue."; exit 1
fi

# get latest NVRs if non specified
if [[ ! $NVRs ]]; then
	echo -n "[INFO] Collect latest codeready-1.0-rhel-7-candidate and codeready-1.0-rhel-8-candidate containers..."
    NVRs=$(\
        brew list-tagged --latest codeready-1.0-rhel-8-candidate | egrep -v "java-container" | grep "codeready-workspaces" | \
            sed -e "s#[\ \t]\+codeready-1.0-rhel-8-candidate.\+##" && \
        brew list-tagged --latest codeready-1.0-rhel-7-candidate | grep -v apb | grep "codeready-workspaces" | \
            sed -e "s#[\ \t]\+codeready-1.0-rhel-7-candidate.\+##"\
    )
    echo "."
    for n in $NVRs; do
    	echo "       + $n"
    done
fi

function parseCommitLog () 
{
    # Update from Jenkins ::
    # crw_master ::
    # Build #246 (2019-02-26 04:23:36 EST) ::
    # che-ls-jdt @ 288b75765175d368480a688c8f3a77ce4758c72d (0.0.3) ::
    # che @ f34f4c6c82de35081351e0b0686b1ae6589735d4 (6.19.0-SNAPSHOT) ::
    # codeready-workspaces @ 184e24bee5bd923b733fa8c9f4b055a9caad40d2 (1.1.0.GA) ::
    # codeready-workspaces-deprecated @ 620a53c5b0a1bbc02ba68e96be94ec3b932c9bee (1.0.0.GA-SNAPSHOT) ::
    # codeready-workspaces-assembly-main.tar.gz
    # codeready-workspaces-stacks-language-servers-dependencies-bayesian.tar.gz
    # codeready-workspaces-stacks-language-servers-dependencies-node.tar.gz
    tarballs=""
    OTHER=""
    JOB_NAME=""
    while [[ "$#" -gt 0 ]]; do
      case $1 in
        'crw_master'|'crw_stable-branch'|'crw-operator-installer-and-ls-deps_'*) JOB_NAME="$1"; shift 2;;
        'Build'*) BUILD_NUMBER="$2"; BUILD_NUMBER=${BUILD_NUMBER#\#}; shift 6;; # trim # from the number, ignore timestamp
        'che-ls-jdt')                      lsj_sha="$3"; echo "  << https://github.com/eclipse/${1}/commit/${lsj_sha:0:7} $4"; shift 5;;
        'che')                             che_sha="$3"; echo "  << https://github.com/eclipse/${1}/commit/${che_sha:0:7} $4"; shift 5;;
        'codeready-workspaces')            crw_sha="$3"; echo "  << https://github.com/redhat-developer/${1}/commit/${crw_sha:0:7} $4"; shift 5;;
        'codeready-workspaces-deprecated') crd_sha="$3"; echo "  << https://github.com/redhat-developer/${1}/commit/${crd_sha:0:7} $4"; shift 5;;
        *'tar.gz') tarballs="${tarballs} $1"; shift 1;;
        *) OTHER="${OTHER} $1"; shift 1;; 
      esac
    done
    if [[ $JOB_NAME ]]; then
        echo "  << ${jenkinsServer}/view/CRW_CI/view/Pipelines/job/${JOB_NAME}/${BUILD_NUMBER}/"
        for t in $tarballs; do
            echo "     ++ ${jenkinsServer}/view/CRW_CI/view/Pipelines/job/${JOB_NAME}/${BUILD_NUMBER}/artifact/**/${t}"
        done
    else
        echo "  << ${jenkinsServer}/view/CRW_CI/view/Pipelines #${BUILD_NUMBER} /${tarballs}"
    fi
}

cd ${WORKSPACE}
for n in $NVRs; do
    echo ""
    # use brew buildinfo to get the repo and sha used to build a given NVR
    repo=$(brew buildinfo $n | grep "Source:" | sed -e "s#Source: git://##")
    sha=${repo#*#}; sha=${sha:0:7} # echo $sha
    repo=${repo%#*}; # echo $repo

    if [[ ! $repo ]]; then
        echo "Brew build not found for $n"; exit 1
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
        echo "== $repo @ $sha =="; echo ""
        git --no-pager log --pretty=format:'%h - %s'  -${numCommits} > $WORKSPACE/${n}_log.txt

        while read l; do
            c_sha=${l:0:7}; # echo $c_sha
            echo -n "https://${repo/\///cgit/}/commit/?id=${c_sha}"
            echo " ${l#${c_sha} }"
            if [[ "$l" == *" [sync] Update from "*" @ "* ]]; then
                # https://github.com/eclipse/che-operator/commit/9ce11db452b4f62a730311b4108fe9ca6bc0b577
                # https://pkgs.devel.redhat.com/cgit/containers/codeready-workspaces/commit/?id=8a13c2ce4dfdbae7c0ac29198339cc39b6881798
                lrepo=${l##*Update from }; lrepo=${lrepo%% @ *}; # echo "   >> lrepo = https://github.com/$lrepo"
                lsha=${l##* @ }
                echo "  << https://github.com/${lrepo}/commit/${lsha}"
            elif [[ "$l" == *" [base] "?"pdate from "*" to "* ]] || [[ "$l" == *" [update base] "?"pdate from "*" to "* ]] || \
                 [[ "$l" == *" [updateDockerfilesFROM.sh] "?"pdate from "*" to "* ]]; then
                # https://access.redhat.com/containers/#/registry.access.redhat.com/rhel7/images/7.6-151.1550575774
                loldbase=${l##*pdate from };loldbase=${loldbase%% to *}; loldbase=${loldbase/://images/}
                lnewbase=${l##* to };lnewbase=${lnewbase/://images/}
                echo "  << https://access.redhat.com/containers/#/registry.access.redhat.com/${loldbase}"
                echo "  >> https://access.redhat.com/containers/#/registry.access.redhat.com/${lnewbase}"
            elif [[ "$l" == *" [get sources] "?"pdate from "* ]]; then
                parseCommitLog ${l##*\[get sources\]}
            fi
            # echo "  == https://${repo/\///cgit/}/commit/?id=${c_sha}"
            echo ""
        done < $WORKSPACE/${n}_log.txt
    cd ..
done
