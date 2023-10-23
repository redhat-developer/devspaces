#!/bin/bash

# script to generate a manifest of all the maven dependencies used to build upstream Che projects

MIDSTM_BRANCH=""
SCRIPT_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
usage () 
{
    echo "Usage: $0 -b devspaces-3.y-rhel-8 -v 3.y.0"
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

cd /tmp || exit
if [[ ! ${WORKSPACE} ]]; then WORKSPACE=${SCRIPT_DIR}; fi
mkdir -p ${WORKSPACE}/${CSV_VERSION}/npm
MANIFEST_FILE="${WORKSPACE}/${CSV_VERSION}/npm/manifest-npm.txt"

rm -fr ${MANIFEST_FILE} ${MANIFEST_FILE/.txt/-raw-unsorted.txt}

git clone --depth 1 --branch ${MIDSTM_BRANCH} https://$GITHUB_TOKEN:x-oauth-basic@github.com/redhat-developer/devspaces-images.git
cd devspaces-images || exit
	git config --global push.default matching
	git config --global hub.protocol https
	git fetch || true
	git checkout --track "origin/${MIDSTM_BRANCH}"
	git pull origin "${MIDSTM_BRANCH}"
		
echo "Generate a list of NPM dependencies:"
# collect dependencies from project yarn.lock (if there)
num=0
c=0
for d in \
devspaces-code \
devspaces-configbump \
devspaces-operator \
devspaces-operator-bundle \
devspaces-dashboard \
\
devspaces-devfileregistry \
devspaces-idea \
devspaces-imagepuller \
devspaces-machineexec \
devspaces-pluginregistry \
\
devspaces-server \
devspaces-traefik \
devspaces-udi \
; do
	#if yarn.lock exists list dependencies
	LOCK_FILES="$(find "$(pwd)/${d}/" -name "yarn.lock")"
	for LOCK_FILE in $LOCK_FILES; do
		(( num = num + 1 ))
	done
	SINGLE_MANIFEST="${WORKSPACE}/${CSV_VERSION}/npm/manifest-npm-${d}.txt"
	rm -fr "${SINGLE_MANIFEST}"
	for LOCK_FILE in $LOCK_FILES; do
		(( c = c + 1 ))
		echo "[$c/$num] Processing $LOCK_FILE ..."
		pushd "${LOCK_FILE/yarn.lock/}" >/dev/null || exit 1
			yarn list --depth=0 | sed \
				-e '/Done in/d' \
				-e '/yarn list/d ' \
				-e 's/[├──└│]//g' \
				-e 's/^[ \t]*//' \
				-e 's/^@//' \
				-e "s/@/:/g" \
				-e "s#^#${d}-container:${CSV_VERSION}/#g"	\
			| sort -uV >> "${SINGLE_MANIFEST}"

			# collect all resolved items too
			grep -E "^  resolved \"" "$LOCK_FILE" | sed -r \
				-e "s#^  resolved \"(https://registry.npmjs.org/|https://registry.yarnpkg.com/)(.+).tgz.*\"#${d}-container::${CSV_VERSION}/\2#" \
				-e "s#^  resolved \"(.*https://)(github.com/.+)\"#${d}-container::${CSV_VERSION}/\2#" \
				-e "s#/([^/]+)/-/#/#" \
				-e "s#\@##" \
				>> "${SINGLE_MANIFEST}"

		popd >/dev/null || exit 1
	done
	if [[ -f "$SINGLE_MANIFEST" ]]; then
		sort -uV "${SINGLE_MANIFEST}" > "${SINGLE_MANIFEST}_"; mv "${SINGLE_MANIFEST}_" "${SINGLE_MANIFEST}"
		cat "${SINGLE_MANIFEST}" >> "${MANIFEST_FILE/.txt/-raw-unsorted.txt}"
	fi
done

#Cleanup
cd .. && rm -fr devspaces-images

echo "Sort and dedupe deps across the repos:"
sort -uV "${MANIFEST_FILE/.txt/-raw-unsorted.txt}" >> ${MANIFEST_FILE}
echo "" >> ${MANIFEST_FILE}
rm -rf "${MANIFEST_FILE/.txt/-raw-unsorted.txt}"

##################################

echo ""
echo "NPM manifest is in file: ${MANIFEST_FILE}"
echo ""

##################################
