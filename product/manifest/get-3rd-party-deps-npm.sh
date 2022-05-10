#!/bin/bash

# script to generate a manifest of all the maven dependencies used to build upstream Che projects

MIDSTM_BRANCH=""
SCRIPT_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
usage () 
{
    echo "Usage: $0 -b crw-2.y-rhel-8 -v 2.y.0"
    exit
}
# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    '-v') CSV_VERSION="$2"; shift 1;;
  esac
  shift 1
done

if [[ ! ${MIDSTM_BRANCH} ]]; then usage; fi
if [[ ! ${CSV_VERSION} ]]; then 
  CSV_VERSION=$(curl -sSLo - https://raw.githubusercontent.com/redhat-developer/codeready-workspaces-operator/${MIDSTM_BRANCH}/manifests/codeready-workspaces.csv.yaml | yq -r .spec.version)
fi

# use x.y (not x.y.z) version, eg., 2.3
CRW_VERSION=$(curl -sSLo - https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/${MIDSTM_BRANCH}/dependencies/VERSION)

cd /tmp || exit
if [[ ! ${WORKSPACE} ]]; then WORKSPACE=${SCRIPT_DIR}; fi
mkdir -p ${WORKSPACE}/${CSV_VERSION}/npm
MANIFEST_FILE="${WORKSPACE}/${CSV_VERSION}/npm/manifest-npmjs.txt"

rm -fr ${MANIFEST_FILE} ${MANIFEST_FILE/.txt/-raw-unsorted.txt}

git clone -q https://$GITHUB_TOKEN:x-oauth-basic@github.com/redhat-developer/devspaces-images.git
cd devspaces-images || exit
	git config --global push.default matching
	git config --global hub.protocol https
	git fetch || true
	git checkout --track "origin/${MIDSTM_BRANCH}"
	git pull origin "${MIDSTM_BRANCH}"
		
echo "Generate a list of NPM dependencies:"
# collect dependencies from project yarn.lock (if there)
for d in \
codeready-workspaces-backup \
codeready-workspaces-configbump \
codeready-workspaces-operator \
codeready-workspaces-operator-bundle \
codeready-workspaces-operator-metadata \
codeready-workspaces-dashboard \
\
codeready-workspaces-devfileregistry \
codeready-workspaces-idea \
codeready-workspaces-imagepuller \
codeready-workspaces-jwtproxy \
codeready-workspaces-machineexec \
\
codeready-workspaces-pluginbroker-artifacts \
codeready-workspaces-pluginbroker-metadata \
codeready-workspaces-plugin-java11-openj9 \
codeready-workspaces-plugin-java11 \
codeready-workspaces-plugin-java8-openj9 \
\
codeready-workspaces-plugin-java8 \
codeready-workspaces-plugin-kubernetes \
codeready-workspaces-plugin-openshift \
codeready-workspaces-pluginregistry \
codeready-workspaces \
\
codeready-workspaces-stacks-cpp \
codeready-workspaces-stacks-dotnet \
codeready-workspaces-stacks-golang \
codeready-workspaces-stacks-php \
codeready-workspaces-theia-dev \
\
codeready-workspaces-theia-endpoint \
codeready-workspaces-theia \
codeready-workspaces-traefik \
; do
	#if yarn.lock exists list dependencies
	LOCK_FILE="$(pwd)/${d}/yarn.lock"
	if [[ -f $LOCK_FILE ]]; then
		cd $d
		SINGLE_MANIFEST="${WORKSPACE}/${CSV_VERSION}/npm/manifest-npmjs-${d}.txt"
		rm -fr ${SINGLE_MANIFEST}
		yarn list --depth=0 | sed \
			-e '/Done in/d' \
			-e '/yarn list/d ' \
			-e 's/[├──└│]//g' \
			-e 's/^[ \t]*//' \
			-e 's/^@//' \
			-e "s/@/:/g" \
		| sort -uV > ${SINGLE_MANIFEST}

		cat ${SINGLE_MANIFEST} >> ${MANIFEST_FILE/.txt/-raw-unsorted.txt}
		cd ..
	fi
done

#Cleanup
cd .. && rm -fr devspaces-images

echo "Sort and dedupe deps across the repos:"
cat ${MANIFEST_FILE/.txt/-raw-unsorted.txt} | sort | uniq >> ${MANIFEST_FILE}
echo "" >> ${MANIFEST_FILE}
rm -rf ${MANIFEST_FILE/.txt/-raw-unsorted.txt}

##################################

echo ""
echo "NPM manifest is in file: ${MANIFEST_FILE}"
echo ""

##################################
