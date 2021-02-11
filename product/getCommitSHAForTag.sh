#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# For a given tag, produce a link to the commit that was used for that tag.
# 
# Eg., for quay.io/crw/plugin-java8:2.y-1 get https://pkgs.devel.redhat.com/cgit/containers/codeready-workspaces-plugin-java8/commit?id=53306c3f99d3b35d4bdeb22b5ef2081e322db7f8

if [[ ! -x /usr/bin/brew ]]; then 
	echo "Brew is required. Please install brewkoji rpm from one of these repos:";
	echo " * http://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-F-27/compose/Everything/x86_64/os/"
	echo " * http://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-RHEL-8/compose/BaseOS/\$basearch/os/"
fi

usage () {
	echo "
Usage: for 1 or more containes in quay or Pulp, compute the NVR, Build URL, and Source commit for that build. eg., 
  $0  quay.io/crw/plugin-java8-rhel8:2.y-1 quay.io/crw/plugin-java11-rhel8:2.y-1 ...
  $0  registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-plugin-java8-rhel8 -j 2.y -n 2      | show last 2 tags
"
exit
}

if [[ $# -lt 1 ]]; then usage; fi

# JOB_BRANCH=2.y
# # could this be computed from $(git rev-parse --abbrev-ref HEAD) ?
# DWNSTM_BRANCH="crw-${JOB_BRANCH}-rhel-8"
NUMTAGS=1 # by default show only the latest tag for each container; or show n latest ones
CONTAINERS=""
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-j') JOB_BRANCH="$2"; DWNSTM_BRANCH="crw-${JOB_BRANCH}-rhel-8"; shift 1;; 
    '-b') DWNSTM_BRANCH="$2"; shift 1;; 
    '--tag') BASETAG="$2"; shift 1;;
    '--candidatetag') candidateTag="$2"; shift 1;;
    '-n') NUMTAGS="$2"; shift 2;;
   *) CONTAINERS="${CONTAINERS} $1"; shift 1;;
  esac
done

if [[ -z ${BASETAG} ]] && [[ ${DWNSTM_BRANCH} ]]; then
	BASETAG=${DWNSTM_BRANCH#*-}
	BASETAG=${BASETAG%%-*}
else
	# if --tag flag used, don't use derived value or fail
	# or, instead of passing in a value, we'll compute it below from the specified image
	true
fi
if [[ -z ${candidateTag} ]] && [[ ${DWNSTM_BRANCH} ]]; then
	candidateTag="${DWNSTM_BRANCH}-container-candidate"
elif [[ -z ${candidateTag} ]] && [[ ${BASETAG} ]]; then
	candidateTag="crw-${BASETAG}-rhel-8-container-candidate"
else
	# instead of passing in a value, we'll compute it below from the specified image
	true
fi

for d in $CONTAINERS; do
	echo "$d"
	d=${d/crw-2-rhel8-/} # special case for operator and metadata images

	#strip off the registry and just find the container name
	dd=${d#*/}
	TAG=${dd##*:}; # echo $TAG
	if [[ ! $candidateTag ]]; then
		# compute BASETAG and use that for candidateTag below, but we're using 
		candidateTagUsed="crw-${TAG%%-*}-rhel-8-container-candidate"
	else
		candidateTagUsed="${candidateTag}"
	fi

	CONTNAME=${dd%%:${TAG}}; CONTNAME=${CONTNAME##*/}; CONTNAME=${CONTNAME%%-rhel8}
	# echo "Search for $CONTNAME :: $TAG"
	# echo "  brew list-tagged ${candidateTag} | grep -E \"${CONTNAME}-container|${CONTNAME}-rhel8-container\" | sed -r -e \"s#${candidateTagUsed}.+##\" | sort -V"
	if [[ $TAG != ${dd} ]]; then
		NVRs=$(brew list-tagged ${candidateTagUsed} | grep -E "${CONTNAME}-container|${CONTNAME}-rhel8-container" | sed -e "s#${candidateTagUsed}.\+##" | sort -V | grep ${TAG})
	else
		NVRs=$(brew list-tagged ${candidateTagUsed} | grep -E "${CONTNAME}-container|${CONTNAME}-rhel8-container" | sed -e "s#${candidateTagUsed}.\+##" | sort -Vr | head -${NUMTAGS})
	fi
	for NVR in $NVRs; do
		echo "     NVR: $NVR"
		# get the BUILD URL
		echo "   Build: "$(brew buildinfo $NVR | grep "BUILD" | sed -e "s#.\+\[\([0-9]\+\)\].*#https://brewweb.engineering.redhat.com/brew/buildinfo?buildID=\1#")
		# get the sources URL
		echo -n "  "; brew buildinfo $NVR | grep Source | sed -e "s#/containers#/cgit/containers#" -e "s#git:#https:#" -e "s%#%/commit?id=%"
		echo
	done
done