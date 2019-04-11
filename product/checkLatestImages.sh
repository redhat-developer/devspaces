#!/bin/bash -e
#
# script to query latest tags of the FROM repos, and update Dockerfiles using the latest base images
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

URLs="\
codeready-workspaces/server codeready-workspaces/server-operator \
codeready-workspaces/stacks-java codeready-workspaces/stacks-node \
codeready-workspaces/stacks-cpp codeready-workspaces/stacks-dotnet codeready-workspaces/stacks-golang \
codeready-workspaces/stacks-php codeready-workspaces/stacks-python \
codeready-workspaces-beta/stacks-java-rhel8 \
"
EXCLUDES="Beta1" # regex pattern of container versions/names to exclude, eg., Beta1 (because version sort thinks 1.0.0.Beta1 > 1.0-12)
WORKDIR=`pwd`
QUIET=0
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-w') WORKDIR="$2"; shift 1;;
    '-u') URLs="$2"; shift 1;;
    '-x') EXCLUDES="$2"; shift 1;;
    '-q') QUIET=1; shift 0;;
    *) OTHER="${OTHER} $1"; shift 0;; 
  esac
  shift 1
done

echo ""
for URLfrag in $URLs; do
	URL="https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/${URLfrag}"
	# echo "URL=$URL"
	QUERY="$(echo $URL | sed -e "s#.\+registry.access.redhat.com/#docker run docker-ls docker-ls tags --registry https://registry.access.redhat.com #g" | tr '\n' ' ')"
	# echo ""; echo "# $QUERY|grep \"^-\"|egrep -v \"\\\"|latest\"|egrep -v "${EXCLUDES}"|sort -V|tail -5"
	LATESTTAG=$(${QUERY} 2>/dev/null|grep "^-"|egrep -v "\"|latest"|egrep -v "${EXCLUDES}"|sed -e "s#^-##" -e "s#[\n\r\ ]\+##g"|sort -V|tail -1)
	if [[ $QUIET -eq 1 ]]; then
		echo "${URLfrag}:${LATESTTAG}"
	else
		echo "* ${URLfrag}:${LATESTTAG} :: https://access.redhat.com/containers/#/registry.access.redhat.com/${URLfrag}/images/${LATESTTAG}"
	fi
done
echo ""