#!/bin/bash -e
#
# script to query the Brew BUILD ID for a given list of NVRs, then produce the list of SHAs associated with those builds
# requires brew CLI to be installed, and an active Kerberos ticket (kinit)

#WORKDIR=`pwd` # NOT USED
#BRANCH=codeready-1.0-rhel-7 # not master # NOT USED

numCommits=10
user="$(whoami)" # default user to fetch sources from pkgs.devel repos
htmlMode=0

while [[ "$#" -gt 0 ]]; do
  case $1 in
    #'-w') WORKDIR="$2"; shift 1;; # NOT USED
    #'-b') BRANCH="$2"; shift 1;; # NOT USED 
    '-c') numCommits="$2"; shift 1;; # eg., 5 or 10 commits to show
    '-n') NVRs="$2"; shift 1;; # eg., codeready-workspaces-server-container-1.1-2
    '-u') user="$2"; shift 1;; # eg., $(whoami), nboldt or crw-build
    '--html') htmlMode=1; shift 0;;
    *) OTHER="${OTHER} $1"; shift 0;; 
  esac
  shift 1
done

if [[ ! ${WORKSPACE} ]]; then WORKSPACE=/tmp; fi

if [[ ! -x /usr/bin/brew ]]; then
	echo "Brew not install in /usr/bin/brew - please install it to continue."; exit 1
fi

if [[ ! $NVRs ]]; then 
	NVRs=$(\
		brew list-tagged --latest codeready-1.0-rhel-8-candidate | egrep -v "java-container" | grep "codeready-workspaces" | \
			sed -e "s#[\ \t]\+codeready-1.0-rhel-8-candidate.\+##" && \
		brew list-tagged --latest codeready-1.0-rhel-7-candidate | grep -v apb | grep "codeready-workspaces" | \
			sed -e "s#[\ \t]\+codeready-1.0-rhel-7-candidate.\+##"\
	)
fi

cd ${WORKSPACE}
for n in $NVRs; do
	echo ""
	# use brew buildinfo to get the repo and sha used to build a given NVR
	repo=$(brew buildinfo $n | grep "Source:" | sed -e "s#Source: git://##")
	sha=${repo#*#}; sha=${sha:0:7} # echo $sha
	repo=${repo%#*}; # echo $repo

	# fetch sources so we can see the log
	if [[ ! -d ${n}_sources ]]; then git clone ssh://${user}@${repo} ${n}_sources -q; fi
	cd ${WORKSPACE}/${n}_sources
		git fetch
		git checkout $sha -q
		echo "== $repo @ $sha =="
		git --no-pager log --graph --pretty=format:'%h - %s'  -${numCommits} > $WORKSPACE/${n}_log.txt

		while read l; do
			echo "$l"
			c_sha=${l#* }; c_sha=${c_sha%% *}; # echo $c_sha
			if [[ "$l" == *" [sync] Update from "*" @ "* ]]; then 
				# https://github.com/eclipse/che-operator/commit/9ce11db452b4f62a730311b4108fe9ca6bc0b577
				# https://pkgs.devel.redhat.com/cgit/containers/codeready-workspaces/commit/?id=8a13c2ce4dfdbae7c0ac29198339cc39b6881798
				lrepo=${l##*Update from }; lrepo=${lrepo%% @ *}; # echo "   >> lrepo = https://github.com/$lrepo"
				lsha=${l##* @ }
				echo "                   << https://github.com/${lrepo}/commit/${lsha}"
				echo "                   >> https://${repo/\///cgit/}/commit/?id=${c_sha}"
			elif [[ "$l" == *" [base] "?"pdate from "*" to "* ]] || [[ "$l" == *" [update base] "?"pdate from "*" to "* ]]; then 
				# https://access.redhat.com/containers/#/registry.access.redhat.com/rhel7/images/7.6-151.1550575774
				loldbase=${l##*pdate from };loldbase=${loldbase%% to *}; loldbase=${loldbase/://images/}
				lnewbase=${l##* to };lnewbase=${lnewbase/://images/}
				echo "                   << https://access.redhat.com/containers/#/registry.access.redhat.com/${loldbase}"
				echo "                   >> https://access.redhat.com/containers/#/registry.access.redhat.com/${lnewbase}"
				echo "                   >> https://${repo/\///cgit/}/commit/?id=${c_sha}"
			elif [[ "$l" == *" [get sources] "?"pdate from "* ]]; then 
				chunks=""
				# Update from Jenkins Build #246 (2019-02-26 04:23:36 EST) :: che-ls-jdt @ 288b75765175d368480a688c8f3a77ce4758c72d (0.0.3) :: che @ f34f4c6c82de35081351e0b0686b1ae6589735d4 (6.19.0-SNAPSHOT) :: codeready-workspaces @ 184e24bee5bd923b733fa8c9f4b055a9caad40d2 (1.1.0.GA) :: codeready-workspaces-assembly-main.tar.gz
			fi
		done < $WORKSPACE/${n}_log.txt
	cd ..
	echo ""
done
