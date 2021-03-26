#!/bin/bash -e
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to query latest tags of the FROM repos, and update Dockerfiles using the latest base images
# REQUIRES: 
#    * skopeo >=0.40 (for authenticated registry queries)
#    * jq to do json queries
# 
# https://registry.redhat.io is v2 and requires authentication to query, so login in first like this:
# docker login registry.redhat.io -u=USERNAME -p=PASSWORD

command -v jq >/dev/null 2>&1 || { echo "jq is not installed. Aborting."; exit 1; }
command -v skopeo >/dev/null 2>&1 || { echo "skopeo is not installed. Aborting."; exit 1; }
checkVersion() {
  if [[  "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]]; then
    # echo "[INFO] $3 version $2 >= $1, can proceed."
	true
  else 
    echo "[ERROR] Must install $3 version >= $1"
    exit 1
  fi
}
checkVersion 0.40 "$(skopeo --version | sed -e "s/skopeo version //")" skopeo

QUIET=0 	# less output - omit container tag URLs
VERBOSE=0	# more output
WORKDIR=$(pwd)

# try to compute branches from currently checked out branch; else fall back to hard coded value
# where to find redhat-developer/codeready-workspaces/${SCRIPTS_BRANCH}/product/getLatestImageTags.sh
SCRIPTS_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ $SCRIPTS_BRANCH != "crw-2."*"-rhel-8" ]]; then
	SCRIPTS_BRANCH="crw-2-rhel-8"
fi
# where to find source branch to update, crw-2.y-rhel-8, 7.yy.x, etc.
SOURCES_BRANCH=${SCRIPTS_BRANCH}

DOCKERFILE="Dockerfile"
MAXDEPTH=2
PR_BRANCH="pr-update-base-images-$(date +%s)"
OPENBROWSERFLAG="" # if a PR is generated, open it in a browser
docommit=1 # by default DO commit the change
dopush=1 # by default DO push the change
buildCommand="echo" # By default, no build will be triggered when a change occurs; use -c for a container-build (or -s for scratch).

checkrecentupdates () {
	# set +e
	for d in $(find ${WORKDIR}/ -maxdepth ${MAXDEPTH} -name ${DOCKERFILE} | sort); do
		pushdir=${d%/${DOCKERFILE}}
		pushd ${pushdir} >/dev/null
			last=$(git lg -1 | grep -v days || true)
			if [[ $last = *[$' \t\n\r']* ]]; then 
				echo "[DEBUG] ${pushdir##*/}"
				echo "[DEBUG] $last" | grep -E "seconds|minutes" || true
				echo
			fi
		popd >/dev/null
	done
	# set -e
}

usage () {
	echo "Usage:   $0 -b [BRANCH] [-w WORKDIR] [-f DOCKERFILE] [-maxdepth MAXDEPTH]"
	echo "Downstream Example: $0 -b ${SOURCES_BRANCH} -w \$(pwd) -f rhel.Dockerfile -maxdepth 2"
	echo "Upstream Examples:

$0 -b 7.yy.x -w dockerfiles/ -f \*from.dockerfile -maxdepth 5 -o # che-theia
$0 -b master -w \$(pwd)      -f rhel.Dockerfile   -maxdepth 4 -o # che-plugin-broker
$0 -b 7.yy.x -w \$(pwd)      -f Dockerfile        -maxdepth 1 --tag '1\.13|8\.[0-9]-' --no-commit # che-operator

"
	echo "Options: 
	--sources-branch, -b    set sources branch (project to update), eg., 7.yy.x
	--scripts-branch, -sb   set scripts branch (project with helper scripts), eg., crw-2.y-rhel-8
	--no-commit, -n    do not commit to BRANCH
	--no-push, -p      do not push to BRANCH
	--tag              regex match to restrict results, eg., '1\.13|8\.[0-9]-' to find golang 1.13 (not 1.14) and any ubi 8-x- tag
	-prb               set a PR_BRANCH; default: pr-new-base-images-(timestamp)
	-o                 open browser if PR generated
	-q, -v             quiet, verbose output
	--help, -h         help
	--check-recent-updates-only   
	                   don't poll for new base images; just report on 
	                   recently changed Dockerfiles in WORKDIR and subdirs
	"
}

if [[ $# -lt 1 ]]; then usage; exit; fi

BASETAG="."
EXCLUDES="latest|-source"
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-w') WORKDIR="$2"; shift 1;;
    '-b'|'--sources-branch') SOURCES_BRANCH="$2"; shift 1;;
    '-sb'|'--scripts-branch') SCRIPTS_BRANCH="$2"; shift 1;;
    '--tag') BASETAG="$2"; shift 1;; # rather than fetching latest tag, grab latest tag matching a pattern like "1.13"
    '-x') EXCLUDES="$2"; shift 1;;
    '-f') DOCKERFILE="$2"; shift 1;;
    '-maxdepth') MAXDEPTH="$2"; shift 1;;
    '-c') buildCommand="rhpkg container-build"; shift 0;; # NOTE: will trigger a new build for each commit, rather than for each change set (eg., Dockefiles with more than one FROM)
    '-s') buildCommand="rhpkg container-build --scratch"; shift 0;;
    '-n'|'--nocommit'|'--no-commit') docommit=0; dopush=0; shift 0;;
    '-p'|'--nopush'|'--no-push') dopush=0; shift 0;;
    '-prb') PR_BRANCH="$2"; shift 1;;
    '-o') OPENBROWSERFLAG="-o"; shift 0;;
    '-q') QUIET=1; shift 0;;
    '-v') QUIET=0; VERBOSE=1; shift 0;;
    '--check-recent-updates-only') QUIET=0; VERBOSE=1; checkrecentupdates; shift 0; exit;;
    '--help'|'-h') usage; exit;;
    *) OTHER="${OTHER} $1"; shift 0;; 
  esac
  shift 1
done

# as seen on https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
vercomp () {
    if [[ $1 == $2 ]]
    then
        vercomp_return=0; return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            vercomp_return=1; return 0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            vercomp_return=2; return 0
        fi
    done
    vercomp_return=0; return 0
}

testvercomp () {
    vercomp $1 $3
    # echo "[DEBUG] vercomp_return=$vercomp_return"
    case $vercomp_return in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac
    if [[ $op != $2 ]]
    then
        testvercomp_return="false"
    else
        testvercomp_return="true"
    fi
}

cherrypickLastCommit() {
	cherryPickBranch=$1
	lastCommit="$(git rev-parse HEAD)"
	git branch ${cherryPickBranch} || true
	git checkout ${cherryPickBranch} || true
	git pull origin ${cherryPickBranch} || true
	git cherry-pick $lastCommit || git commit --allow-empty -sm "${lastCommitComment}"
	git push origin ${cherryPickBranch}
}

pushedIn=0
for d in $(find ${WORKDIR}/ -maxdepth ${MAXDEPTH} -name ${DOCKERFILE} | sort -r); do
	if [[ -f ${d} ]]; then
		echo ""
		echo "# Checking ${d} ..."
		# pull latest commits
		if [[ -d ${d%%/${DOCKERFILE}} ]]; then pushd ${d%%/${DOCKERFILE}} >/dev/null; pushedIn=1; fi
		if [[ "${d%/${DOCKERFILE}}" == *"-rhel8" ]]; then
			BRANCHUSED=${SOURCES_BRANCH/rhel-7/rhel-8}
		else
			BRANCHUSED=${SOURCES_BRANCH}
		fi
		git branch --set-upstream-to=origin/${BRANCHUSED} ${BRANCHUSED} -q || true
		git checkout ${BRANCHUSED} -q || true 
		git pull -q || true
		if [[ ${pushedIn} -eq 1 ]]; then popd >/dev/null; pushedIn=0; fi

		QUERY=""
		FROMPREFIX=""
		LATESTTAG=""
		URLs=$(cat $d | grep FROM -B1);
		for URL in $URLs; do
			URL=${URL#registry.access.redhat.com/}
			URL=${URL#registry.redhat.io/}
			if [[ $VERBOSE -eq 1 ]]; then echo "[DEBUG] URL=$URL"; fi
			if [[ $URL == "https"* ]]; then 
				# QUERY="$(echo $URL | sed -e "s#.\+\(registry.redhat.io\|registry.access.redhat.com\)/#skopeo inspect docker://registry.redhat.io/#g")"
				# if [[ ${QUIET} -eq 0 ]]; then echo "# $QUERY| jq .RepoTags| grep -E -v \"\[|\]|latest|-source\"|sed -e 's#.*\"\(.\+\)\",*#- \1#'|sort -V|tail -5"; fi
				# LATESTTAG=$(${QUERY} 2>/dev/null| jq .RepoTags|grep -E -v "\[|\]|latest|-source"|sed -e 's#.*\"\(.\+\)\",*#\1#'|sort -V|tail -1)
				FROMPREFIX=$(echo $URL | sed -e "s#.\+registry.access.redhat.com/##g")

				# get getLatestImageTags script
				# TODO CRW-1511 sometimes this returns a 404 instead of a valid script. Why?
				if [[ ! -x /tmp/getLatestImageTags.sh ]]; then 
					pushd /tmp >/dev/null || exit 1
					glit=https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/${SCRIPTS_BRANCH}/product/getLatestImageTags.sh
					if [[ $VERBOSE -eq 1 ]]; then echo "[DEBUG] Downloading $glit ..."; fi
					curl -sSLO $glit && chmod +x getLatestImageTags.sh
					popd >/dev/null || exit 1
				fi
				LATESTTAG=$(/tmp/getLatestImageTags.sh -c ${FROMPREFIX} -x "${EXCLUDES}" --tag "${BASETAG}")
				LATESTTAG=${LATESTTAG##*:}

				LATE_TAGver=${LATESTTAG%%-*} # 1.0
				LATE_TAGrev=${LATESTTAG##*-} # 15.1553789946 or 15
				LATE_TAGrevbase=${LATE_TAGrev%%.*} # 15
				LATE_TAGrevsuf=${LATE_TAGrev##*.} # 1553789946 or 15
				if [[ $VERBOSE -eq 1 ]]; then echo "[DEBUG] LATE_TAGver=$LATE_TAGver; LATE_TAGrev=$LATE_TAGrev; LATE_TAGrevbase=$LATE_TAGrevbase; LATE_TAGrevsuf=$LATE_TAGrevsuf"; fi
				echo "+ ${FROMPREFIX}:${LATESTTAG}" # jboss-eap-7/eap72-openshift:1.0-15
			elif [[ $URL ]] && [[ $URL == "${FROMPREFIX}:"* ]]; then
				if [[ ${LATESTTAG} ]]; then
					# CRW-205 Support using unpublished freshmaker builds
					# Do not replace 1.0-15.1553789946 with "newer" 1.0-15; instead, keep 1.0-15.1553789946 version
					# URL = jboss-eap-7/eap72-openshift:1.0-15.1553789946
					CURR_TAGver=${URL##*:}; CURR_TAGver=${CURR_TAGver%%-*} # 1.0
					CURR_TAGrev=${URL##*-} # 15.1553789946 or 15
					CURR_TAGrevbase=${CURR_TAGrev%%.*} # 15
					CURR_TAGrevsuf=${CURR_TAGrev##*.} # 1553789946 or 15
					# if any of the rev varibles contain a colon, then set them to 0 instead to avoid string to number mismatch
					if [[ "${CURR_TAGrev}" == *":"* ]] || [[ "${CURR_TAGrevbase}" == *":"* ]] || [[ "${CURR_TAGrevsuf}" == *":"* ]]; then
						CURR_TAGrev=0
						CURR_TAGrevbase=0
						CURR_TAGrevsuf=0
					fi
					if [[ $VERBOSE -eq 1 ]]; then echo "[DEBUG] 
#CURR_TAGver=$CURR_TAGver; CURR_TAGrev=$CURR_TAGrev; CURR_TAGrevbase=$CURR_TAGrevbase; CURR_TAGrevsuf=$CURR_TAGrevsuf
#LATE_TAGver=$LATE_TAGver; LATE_TAGrev=$LATE_TAGrev; LATE_TAGrevbase=$LATE_TAGrevbase; LATE_TAGrevsuf=$LATE_TAGrevsuf"; fi

					if [[ ${LATE_TAGrevsuf} != ${CURR_TAGrevsuf} ]] || [[ "${LATE_TAGver}" != "${CURR_TAGver}" ]] || [[ "${LATE_TAGrevbase}" != "${CURR_TAGrevbase}" ]]; then
						echo "- ${URL}"
					fi
					# TODO: try using testvercomp against the full tag versions w/ suffixes, eg., 8.16.0-0 ">" 8.15.1-1.1554788812
					if [[ "${LATE_TAGver}" != "${CURR_TAGver}" ]] || [[ ${LATE_TAGrevbase} -gt ${CURR_TAGrevbase} ]] || [[ ${LATE_TAGrevsuf} -gt ${CURR_TAGrevsuf} ]]; then
						testvercomp "${LATE_TAGver}" ">" "${CURR_TAGver}"
						if [[ "${testvercomp_return}" == "true" ]] || [[ ${LATE_TAGrevsuf} -ge ${CURR_TAGrevsuf} ]] || [[ ${LATE_TAGrevbase} -gt ${CURR_TAGrevbase} ]]; then # fix the ${DOCKERFILE}
							echo "++ $d "
							sed -i -e "s#${URL}#${FROMPREFIX}:${LATESTTAG}#g" $d

							# commit change and push it
							if [[ -d ${d%%/${DOCKERFILE}} ]]; then pushd ${d%%/${DOCKERFILE}} >/dev/null; pushedIn=1; fi
							# set -x
							if [[ ${docommit} -eq 1 ]]; then 
								git add ${DOCKERFILE} || true
								git commit -s -m "[base] Update from ${URL} to ${FROMPREFIX}:${LATESTTAG}" ${DOCKERFILE}
								git pull origin "${BRANCHUSED}"
								if [[ ${dopush} -eq 1 ]]; then
									PUSH_TRY="$(git push origin "${BRANCHUSED}" 2>&1 || git push origin "${PR_BRANCH}" || true)"

									# shellcheck disable=SC2181
									if [[ $? -gt 0 ]] || [[ $PUSH_TRY == *"protected branch hook declined"* ]]; then
										# create pull request if target branch is restricted access
										lastCommitComment="$(git log -1 --pretty=%B)"
										cherrypickLastCommit "${PR_BRANCH}"
										if [[ $(/usr/local/bin/hub version 2>/dev/null || true) ]] || [[ $(which hub 2>/dev/null || true) ]]; then
											hub pull-request -f -m "${lastCommitComment}

${lastCommitComment}" -b "${BRANCHUSED}" -h "${PR_BRANCH}" "${OPENBROWSERFLAG}" || true 
										else
											echo "# Warning: hub is required to generate pull requests. See https://hub.github.com/ to install it."
											echo -n "# To manually create a pull request, go here: "
											git config --get remote.origin.url | sed -r -e "s#:#/#" -e "s#git@#https://#" -e "s#\.git#/tree/${PR_BRANCH}/#"
										fi
									fi
								fi
							fi
							set +x
							if [[ ${buildCommand} != "echo" ]] || [[ $VERBOSE -eq 1 ]]; then echo "# ${buildCommand}"; fi
							${buildCommand} &
							echo
							if [[ ${pushedIn} -eq 1 ]]; then popd >/dev/null; pushedIn=0; fi
							fixedFiles="${fixedFiles} $d"
						else
							echo "# No change applied for ${URL} -> ${LATESTTAG}"
						fi
					fi
				fi
			fi
		done
	fi
done 
sleep 10s & wait

echo ""
if [[ $fixedFiles ]]; then
	echo "[base] Updated:"
	# if WORKSPACE defined, trim that off; if not, just trim /
	for d in $fixedFiles; do echo " ${d#${WORKSPACE}/}"; done
	echo ""
else
	if [[ ${QUIET} -eq 0 ]]; then echo "[base] No Dockerfiles changed - no new base images found."; fi
fi
