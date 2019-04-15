#!/bin/bash -e
#
# script to query latest tags for a given list of imags in RHCC
# requires docker-ls container to be built locally -- see https://github.com/mayflower/docker-ls
# 
# thankfully, the https://registry.access.redhat.com is v2 and does not require authentication to query

if [[ $(docker run docker-ls docker-ls 2>&1) == *"Unable to find image"* ]]; then 
	echo "Installing docker-ls ..."
	rm -fr /tmp/docker-ls
	pushd /tmp >/dev/null
	git clone -q --depth=1 https://github.com/mayflower/docker-ls && cd docker-ls && docker build -t docker-ls .
	rm -fr /tmp/docker-ls
	popd >/dev/null
fi

# default list of CRW containers to query
CRW_CONTAINERS="\
codeready-workspaces/server codeready-workspaces/server-operator \
codeready-workspaces/stacks-java codeready-workspaces/stacks-node \
codeready-workspaces/stacks-cpp codeready-workspaces/stacks-dotnet codeready-workspaces/stacks-golang \
codeready-workspaces/stacks-php codeready-workspaces/stacks-python \
codeready-workspaces-beta/stacks-java-rhel8 \
"

# regex pattern of container versions/names to exclude, eg., Beta1 (because version sort thinks 1.0.0.Beta1 > 1.0-12)
EXCLUDES="\^" 

# less output - omit container tag URLs
QUIET=0
VERBOSE=0
NUMTAGS=1

usage () {
	echo "
Usage: 
  $0 -crw                                                       | use default list of CRW images in RHCC
  $0 -c \"rhoar-nodejs/nodejs-10 jboss-eap-7/eap72-openshift\"    | use specific list of RHCC images
  $0 -c ubi7 -c ubi8:8.0 --pulp -n 5                            | check pulp registry; show 8.0* tags; show 5 tags per container
"
	exit
}
if [[ $# -lt 1 ]]; then usage; fi

REGISTRY="https://registry.access.redhat.com" # or "http://brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888"
CONTAINERS=""
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-crw') CONTAINERS="${CRW_CONTAINERS}"; EXCLUDES="Beta1"; shift 0;;
    '-c') CONTAINERS="${CONTAINERS} $2"; shift 1;;
    '-x') EXCLUDES="$2"; shift 1;;
    '-q') QUIET=1; shift 0;;
    '-v') QUIET=0; VERBOSE=1; shift 0;;
    '-r') REGISTRY="$2"; shift 1;;
    '-p'|'--pulp') REGISTRY="http://brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888"; EXCLUDES="candidate|guest|containers"; VERBOSE=0; QUIET=1; shift 0;;
    '-n') NUMTAGS="$2"; shift 1;;
    '-h') usage;;
  esac
  shift 1
done

if [[ ${CONTAINERS} == "" ]]; then usage; fi

if [[ $(docker run docker-ls docker-ls 2>&1) == *"Unable to find image"* ]]; then
	echo "Installing docker-ls ..."
	rm -fr /tmp/docker-ls
	pushd /tmp >/dev/null
	git clone -q --depth=1 https://github.com/mayflower/docker-ls && cd docker-ls && docker build -t docker-ls .
	rm -fr /tmp/docker-ls
	popd >/dev/null
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
	# echo "URL=$URL"
	QUERY="$(echo $URL | sed -e "s#.\+registry.access.redhat.com/#docker run docker-ls docker-ls tags --allow-insecure --registry ${REGISTRY} #g" | tr '\n' ' ')"
	if [[ $VERBOSE -eq 1 ]]; then 
		echo ""; echo "# $QUERY|grep \"${URLfragtag}\"|egrep -v \"\\\"|latest\"|egrep -v \"${EXCLUDES}\"|sort -V|tail"; 
	fi
	LATESTTAGs=$(${QUERY} 2>/dev/null|grep "${URLfragtag}"|egrep -v "\"|latest"|egrep -v "${EXCLUDES}"|sed -e "s#^-##" -e "s#[\n\r\ ]\+##g"|sort -V|tail -${NUMTAGS})
	for LATESTTAG in ${LATESTTAGs}; do
		if [[ $REGISTRY = *"registry.access.redhat.com"* ]]; then
			if [[ $QUIET -eq 1 ]]; then
				echo "${URLfrag}:${LATESTTAG}"
			else
				echo "* ${URLfrag}:${LATESTTAG} :: https://access.redhat.com/containers/#/registry.access.redhat.com/${URLfrag}/images/${LATESTTAG}"
			fi
		else
			echo "${REGISTRY##*://}/${URLfrag}:${LATESTTAG}"
		fi
	done
done
echo ""