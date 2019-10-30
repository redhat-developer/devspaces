#!/bin/bash
#
# For a given tag, produce a link to the commit that was used for that tag.
# 
# Eg., for quay.io/crw/stacks-java:1.2-10 get https://pkgs.devel.redhat.com/cgit/containers/codeready-workspaces-stacks-java/commit?id=53306c3f99d3b35d4bdeb22b5ef2081e322db7f8

if [[ ! -x /usr/bin/brew ]]; then 
	echo "Brew is required. Please install brewkoji rpm from one of these repos:";
	echo " * http://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-F-27/compose/Everything/x86_64/os/"
	echo " * http://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-RHEL-7/compose/Workstation/x86_64/os/"
fi

usage () {
	echo "
Usage: for 1 or more containes in quay or Pulp, compute the NVR, Build URL, and Source commit for that build. eg., 
  $0  quay.io/crw/stacks-java-rhel8:1.2-10 quay.io/crw/stacks-java-rhel8:1.2-9 ...
  $0  registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-stacks-java-rhel8 -n 2      | show last 2 tags
"
exit
}

if [[ $# -lt 1 ]]; then usage; fi

NUMTAGS=1 # by default show only the latest tag for each container; or show n latest ones

CONTAINERS=""
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-n') NUMTAGS="$2"; shift 2;;
   *) CONTAINERS="${CONTAINERS} $1"; shift 1;;
  esac
done

for d in $CONTAINERS; do
	echo "$d"
	#strip off the registry and just find the container name
	dd=${d#*/}
	TAG=${dd##*:}; # echo $TAG
	CONTNAME=${dd%%:${TAG}}; CONTNAME=${CONTNAME##*/}; CONTNAME=${CONTNAME%%-rhel8}
	# echo "Searching for $CONTNAME :: $TAG ... "
	if [[ $TAG != ${dd} ]]; then
		NVRs=$(brew list-tagged crw-1.2-rhel-8-candidate | grep ${CONTNAME} | sed -e "s#crw-1.2-rhel-8-candidate.\+##" | sort -V | grep ${TAG})
	else
		NVRs=$(brew list-tagged crw-1.2-rhel-8-candidate | grep ${CONTNAME} | sed -e "s#crw-1.2-rhel-8-candidate.\+##" | sort -Vr | head -${NUMTAGS})
	fi
	for NVR in $NVRs; do
		echo "     NVR: $NVR"
		# get the BUILD URL
		echo "   Build: "$(brew buildinfo $NVR | grep "BUILD" | sed -e "s#.\+\[\([0-9]\+\)\].*#https://brewweb.engineering.redhat.com/brew/buildinfo?buildID=\1#")
		# # get the sources URL
		echo -n "  "; brew buildinfo $NVR | grep Source | sed -e "s#/containers#/cgit/containers#" -e "s#git:#https:#" -e "s%#%/commit?id=%"
		echo
	done
done