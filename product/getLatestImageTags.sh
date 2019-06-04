#!/bin/bash
#
# script to query latest tags for a given list of imags in RHCC
# requires brew for pulp queries, skopeo (for authenticated registry queries) and jq to do json queries
# 
# https://registry.redhat.io is v2 and requires authentication to query, so login in first like this:
# docker login registry.redhat.io -u=USERNAME -p=PASSWORD

if [[ ! -x /usr/bin/brew ]]; then 
	echo "Brew is required. Please install brewkoji rpm from one of these repos:";
	echo " * http://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-F-27/compose/Everything/x86_64/os/"
	echo " * http://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-RHEL-7/compose/Workstation/x86_64/os/"
fi

if [[ ! -x /usr/bin/skopeo ]]; then 
	echo "This script requires skopeo. Please install it."
	exit 1
fi

if [[ ! -x /usr/bin/jq ]]; then 
	echo "This script requires jq. Please install it."
	exit 1
fi

# default list of CRW containers to query
CRW_CONTAINERS_RHCC="\
codeready-workspaces/server-operator-rhel8 codeready-workspaces/server-rhel8 \
codeready-workspaces/stacks-cpp-rhel8 codeready-workspaces/stacks-dotnet-rhel8 codeready-workspaces/stacks-golang-rhel8 \
codeready-workspaces/stacks-java-rhel8 codeready-workspaces/stacks-node-rhel8 \
codeready-workspaces/stacks-php-rhel8 codeready-workspaces/stacks-python-rhel8 \
codeready-workspaces/stacks-node"
CRW_CONTAINERS_PULP="\
codeready-workspaces/operator-rhel8 codeready-workspaces/server-rhel8 \
codeready-workspaces/stacks-cpp-rhel8 codeready-workspaces/stacks-dotnet-rhel8 codeready-workspaces/stacks-golang-rhel8 \
codeready-workspaces/stacks-java-rhel8 codeready-workspaces/stacks-node-rhel8 \
codeready-workspaces/stacks-php-rhel8 codeready-workspaces/stacks-python-rhel8 \
codeready-workspaces/stacks-node"

# regex pattern of container versions/names to exclude, eg., Beta1 (because version sort thinks 1.0.0.Beta1 > 1.0-12)
EXCLUDES="\^" 

QUIET=0 	# less output - omit container tag URLs
VERBOSE=0	# more output
NUMTAGS=1 # by default show only the latest tag for each container; or show n latest ones
SHOWHISTORY=0 # compute the base images defined in the Dockerfile's FROM statement(s): NOTE: requires that the image be pulled first 
SHOWNVR=0; # show NVR format instead of repo/container:tag format
usage () {
	echo "
Usage: 
  $0 --crw                                                   | use default list of CRW images in RHCC Prod
  $0 --crw -r registry.access.stage.redhat.com               | use default list of CRW images in RHCC Stage
  $0 -c 'rhoar-nodejs/nodejs-10 jboss-eap-7/eap72-openshift' | use specific list of RHCC images
  $0 -c ubi7 -c ubi8:8.0 --pulp -n 5                         | check pulp registry; show 8.0* tags; show 5 tags per container
  $0 -c ubi7 -c ubi8:8.0 --stage -n 5                        | check RHCC stage registry; show 8.0* tags; show 5 tags per container
  $0 -c pivotaldata/centos --docker --dockerfile             | check docker registry; show Dockerfile contents (requires dfimage)
  $0 --crw --pulp --nvr                                      | check for latest images in pulp; output NVRs can be copied to Errata
"
	exit
}
if [[ $# -lt 1 ]]; then usage; fi

REGISTRY="https://registry.redhat.io" # or http://brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888 or https://registry-1.docker.io or https://registry.access.redhat.com
CONTAINERS=""
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--crw') CONTAINERS="${CRW_CONTAINERS_RHCC}"; EXCLUDES="Beta1"; shift 0;;
    '-c') CONTAINERS="${CONTAINERS} $2"; shift 1;;
    '-x') EXCLUDES="$2"; shift 1;;
    '-q') QUIET=1; shift 0;;
    '-v') QUIET=0; VERBOSE=1; shift 0;;
    '-r') REGISTRY="$2"; shift 1;;
    '--stage') REGISTRY="http://registry.stage.redhat.io"; shift 1;;
    '-p'|'--pulp') REGISTRY="http://brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888"; EXCLUDES="candidate|guest|containers"; shift 0;;
    '-d'|'--docker') REGISTRY=""; shift 0;;
           '--quay') REGISTRY="http://quay.io"; shift 0;;
    '-n') NUMTAGS="$2"; shift 1;;
    '--dockerfile') SHOWHISTORY=1; shift 0;;
    '--nvr') SHOWNVR=1; shift 0;;
    '-h') usage;;
  esac
  shift 1
done
if [[ ${REGISTRY} != "" ]]; then 
	REGISTRYSTRING="--registry ${REGISTRY}"
	REGISTRYPRE="${REGISTRY##*://}/"
	if [[ ${REGISTRY} == *"brew-pulp-docker01"* ]]; then
		if [[ ${CONTAINERS} == "${CRW_CONTAINERS_RHCC}" ]] || [[ ${CONTAINERS} == "" ]]; then CONTAINERS="${CRW_CONTAINERS_PULP}"; fi
	elif [[ ${REGISTRY} == *"quay.io"* ]]; then
		if [[ ${CONTAINERS} == "${CRW_CONTAINERS_RHCC}" ]] || [[ ${CONTAINERS} == "" ]]; then
			CONTAINERS="${CRW_CONTAINERS_PULP}"; CONTAINERS="${CONTAINERS//codeready-workspaces/crw}"
		fi
	fi
else
	REGISTRYSTRING=""
	REGISTRYPRE=""
fi

# see https://hub.docker.com/r/laniksj/dfimage
if [[ $SHOWHISTORY -eq 1 ]]; then
	if [[ ! $(docker images | grep  laniksj/dfimage) ]]; then 
		echo "Installing dfimage ..."
		docker pull laniksj/dfimage 2>&1
	fi
fi

if [[ ${CONTAINERS} == "" ]]; then usage; fi

# special case!
if [[ ${REGISTRY} == "http://brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888" ]] && [[ ${CONTAINERS} == "${CRW_CONTAINERS_PULP}" ]] && [[ ${SHOWNVR} -eq 1 ]]; then
	for containername in ${CONTAINERS}; do
		if [[ $containername == "codeready-workspaces/stacks-node" ]]; then canditateTag="codeready-1.0-rhel-7-candidate"; else canditateTag="crw-1.2-rhel-8-candidate"; fi
		brew list-tagged ${canditateTag} | grep "${containername/\//-}" | sort -V | tail -${NUMTAGS} | sed -e "s#[\ \t]\+${canditateTag}.\+##"
	done
	exit
fi

echo ""
for URLfrag in $CONTAINERS; do
	URLfragtag=${URLfrag##*:}
	if [[ ${URLfragtag} == ${URLfrag} ]]; then # tag appended on url
		URL="https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/${URLfrag}"
		URLfragtag="^-"
	else
		URL="https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/${URLfrag%%:*}"
		URLfragtag="^- ${URLfragtag}"
	fi
	# if [[ $VERBOSE -eq 1 ]]; then echo "URL=$URL"; fi
	QUERY="$(echo $URL | sed -e "s#.\+\(registry.redhat.io\|registry.access.redhat.com\)/#skopeo inspect docker://registry.redhat.io/#g")"
	if [[ $VERBOSE -eq 1 ]]; then 
		echo ""; echo "# $QUERY | jq .RepoTags | egrep -v \"\[|\]|latest\" | sed -e 's#.*\"\(.\+\)\",*#- \1#' | sort -V|tail -5"
	fi
	LATESTTAGs=$(${QUERY} 2>/dev/null | jq .RepoTags | egrep -v "\[|\]|latest" | sed -e 's#.*\"\(.\+\)\",*#- \1#' | sort -V | grep "${URLfragtag}"|egrep -v "\"|latest"|egrep -v "${EXCLUDES}"|sed -e "s#^-##" -e "s#[\n\r\ ]\+##g"|tail -${NUMTAGS})
	if [[ ! ${LATESTTAGs} ]]; then # try again with -container suffix
		QUERY="$(echo ${URL}-container | sed -e "s#.\+\(registry.redhat.io\|registry.access.redhat.com\)/#skopeo inspect docker://registry.redhat.io/#g")"
		if [[ $VERBOSE -eq 1 ]]; then 
			echo ""; echo "# $QUERY | jq .RepoTags | egrep -v \"\[|\]|latest\" | sed -e 's#.*\"\(.\+\)\",*#- \1#' | sort -V|tail -5" 
		fi
		LATESTTAGs=$(${QUERY} 2>/dev/null | jq .RepoTags | egrep -v "\[|\]|latest" | sed -e 's#.*\"\(.\+\)\",*#- \1#' | sort -V | grep "${URLfragtag}"|egrep -v "\"|latest"|egrep -v "${EXCLUDES}"|sed -e "s#^-##" -e "s#[\n\r\ ]\+##g"|tail -${NUMTAGS})
	fi

	for LATESTTAG in ${LATESTTAGs}; do
		if [[ "$REGISTRY" = *"registry.access.redhat.com"* ]]; then
			if [[ $QUIET -eq 1 ]]; then
				echo "${URLfrag%%:*}:${LATESTTAG}"
			else
				echo "* ${URLfrag%%:*}:${LATESTTAG} :: https://access.redhat.com/containers/#/registry.access.redhat.com/${URLfrag}/images/${LATESTTAG}"
			fi
		elif [[ "${REGISTRY}" != "" ]]; then
			if [[ $VERBOSE -eq 1 ]]; then 
				echo "${REGISTRYPRE}${URLfrag%%:*}:${LATESTTAG}"
			elif [[ ${SHOWNVR} -eq 1 ]]; then
				ufrag=${URLfrag%%:*}; ufrag=${ufrag/\//-}
				echo "${ufrag}-container-${LATESTTAG}"
			elif [[ $QUIET -eq 1 ]]; then
				echo "${URLfrag%%:*}:${LATESTTAG}"
			else
				echo "${URLfrag%%:*}:${LATESTTAG} :: ${REGISTRY}"
			fi
		else
			echo "${URLfrag}:${LATESTTAG}"
		fi
		if [[ ${SHOWHISTORY} -eq 1 ]]; then
			if [[ $VERBOSE -eq 1 ]]; then echo "Pull ${REGISTRYPRE}${URLfrag}:${LATESTTAG} ..."; fi
			if [[ ! $(docker images | grep ${URLfrag} | grep ${LATESTTAG}) ]]; then 
				if [[ $VERBOSE -eq 1 ]]; then 
					docker pull ${REGISTRYPRE}${URLfrag}:${LATESTTAG}
				else
					docker pull ${REGISTRYPRE}${URLfrag}:${LATESTTAG} >/dev/null
				fi
			fi
			cnt=0
			IMAGE_INFO="$(docker images | grep ${URLfrag} | grep ${LATESTTAG})"
			if [[ $VERBOSE -eq 1 ]]; then echo $IMAGE_INFO; fi
			for bits in $IMAGE_INFO; do 
				let cnt=cnt+1
				if [[ ${cnt} -eq 3 ]]; then 
					# echo "Image ID = ${bits}"
					docker run -v /var/run/docker.sock:/var/run/docker.sock --rm laniksj/dfimage ${bits} # | grep FROM
					break
				fi
			done
			if [[ $VERBOSE -eq 1 ]]; then echo "Purge ${REGISTRYPRE}${URLfrag}:${LATESTTAG} ..."; fi
			docker image rm -f ${REGISTRYPRE}${URLfrag}:${LATESTTAG} >/dev/null
		fi
	done
	if [[ $NUMTAGS -gt 1 ]] || [[ ${SHOWHISTORY} -eq 1 ]]; then echo ""; fi
done
echo ""