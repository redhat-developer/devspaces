#!/bin/bash

# script to generate a manifest of all the 3rd party deps not built in OSBS, but built in Jenkins or imported from upstream community.

JENKINS=https://main-jenkins-csb-crwqe.apps.ocp4.prod.psi.redhat.com/job/CRW_CI/job

MIDSTM_BRANCH=""
SCRIPT_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
usage () 
{
    echo "Usage: $0 -b $(git rev-parse --abbrev-ref HEAD) -v 2.y.0"
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
CRW_VERSION=$(curl -sSLo - https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/${MIDSTM_BRANCH}/dependencies/VERSION)

EXCLUDE_FILES="e2e|kubernetes"
EXCLUDE_LINES="eclipse-che/che-theia|redhat-developer/codeready-workspaces/|redhat-developer/codeready-workspaces-theia|SHASUMS256.txt|CDN_PREFIX|cdn.stage.redhat.com|api.github.com|GITHUB_LIMIT|GITHUB_TOKEN|THEIA_GITHUB_REPO|.git$|.asc|/debian$|/debian/$|APKINDEX.tar.gz|get-pip|=http"
EXCLUDE_LINES2="che:theia"

cd /tmp || exit
if [[ ! ${WORKSPACE} ]]; then WORKSPACE=${SCRIPT_DIR}; fi
mkdir -p "${WORKSPACE}/${CSV_VERSION}/theia"
MANIFEST_FILE="${WORKSPACE}/${CSV_VERSION}/theia/manifest-theia.txt"
LOG_FILE="${WORKSPACE}/${CSV_VERSION}/theia/manifest-theia_log.txt"

function log () {
	echo "$1" | tee -a "${LOG_FILE}"
}

rm -f "${MANIFEST_FILE}" "${MANIFEST_FILE}".2 "${MANIFEST_FILE}".3 "${LOG_FILE}"
[[ "${MIDSTM_BRANCH}" == "crw-2-rhel-8" ]] && JOB_BRANCH="2.x" || JOB_BRANCH="${CRW_VERSION}"
echo "Parsing ${JENKINS}/crw-theia-sources_${JOB_BRANCH}/lastSuccessfulBuild/consoleText ..."
curl -sSL -o "${MANIFEST_FILE}".2 "${JENKINS}/crw-theia-sources_${JOB_BRANCH}/lastSuccessfulBuild/consoleText"
CHE_THEIA_BRANCH=$(grep "echo SOURCE_BRANCH=" "${MANIFEST_FILE}".2 | sed -r -e "s#.+echo SOURCE_BRANCH=(.+)#\1#") # 7.yy.x
rm -f "${MANIFEST_FILE}.2"

if [[ -z $CHE_THEIA_BRANCH ]]; then 
	echo "[ERROR] Could not compute CHE_THEIA_BRANCH from ${JENKINS}/crw-theia-sources_${JOB_BRANCH}/lastSuccessfulBuild/consoleText"
	exit 1
fi

TMPDIR=$(mktemp -d)
pushd "$TMPDIR" >/dev/null || exit
	git clone https://$GITHUB_TOKEN:x-oauth-basic@github.com/eclipse-che/che-theia.git 
	cd che-theia || exit
		git config --global push.default matching
		git config --global hub.protocol https
		git fetch || true
		git checkout --track "origin/${CHE_THEIA_BRANCH}"
		git pull origin "${CHE_THEIA_BRANCH}"
		# collect dependencies from theia project yarn.lock
		# shellcheck disable=SC2129
		yarn list --depth=0 | sed \
				-e '/Done in/d' \
				-e '/yarn list/d ' \
				-e 's/[├──└│]//g' \
				-e 's/^[ \t]*//' \
				-e 's/^@//' \
				-e "s/@/:/g" \
				-e "s#^#codeready-workspaces-theia-rhel8-container:${CRW_VERSION}/#g"	\
		| sort -uV > ${MANIFEST_FILE}.yarn

		podman pull quay.io/crw/theia-rhel8:${CRW_VERSION}

		# copy plugin directories into the filesystem, in order to execute yarn commands to obtain yarn.lock file, and list dependencies from it
		curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/${MIDSTM_BRANCH}/product/containerExtract.sh
		chmod +x  containerExtract.sh
		./containerExtract.sh quay.io/crw/theia-rhel8:2.12 --tar-flags home/theia/plugins/**
		find /tmp/quay.io-crw-theia-rhel8-* -path '*extension/node_modules' -exec sh -c "cd {}/.. && yarn --silent && yarn list --depth=0" \; >> ${MANIFEST_FILE}.plugin-extensions
		sed \
				-e '/Done in/d' \
				-e '/yarn list/d ' \
				-e 's/[├──└│]//g' \
				-e 's/^[ \t]*//' \
				-e 's/^@//' \
				-e "s/@/:/g" \
				-e "s#^#codeready-workspaces-theia-rhel8-container:${CRW_VERSION}/#g"	\
		${MANIFEST_FILE}.plugin-extensions | sort -uV >> ${MANIFEST_FILE}
		
		echo >> ${MANIFEST_FILE}

		# collect global yarn dependencies, obtained from yarn.lock file in the theia-container yarn installation
		podman run --rm  --entrypoint /bin/sh "quay.io/crw/theia-rhel8:${CRW_VERSION}" \
			-c "cat /usr/local/share/.config/yarn/global/yarn.lock" | grep -e 'version "' -B1 | \
			sed -r -e '/^--$/d' \
			-e 's/^"@//' > "${MANIFEST_FILE}.globalyarn"
		while IFS= read -r dependency
		do
			read -r version
			dependency=$(echo ${dependency} | tr -d '"' | cut -f1 -d"@")
			version=$(echo ${version} | cut -f2 -d" " | tr -d '"')
			echo "codeready-workspaces-theia-rhel8-container:${CRW_VERSION}/${dependency}:${version}" >> "${MANIFEST_FILE}.yarn"
		done < "${MANIFEST_FILE}.globalyarn"
		
		cat ${MANIFEST_FILE}.yarn | sort -uV >> ${MANIFEST_FILE}
		echo >> ${MANIFEST_FILE}

		cat generator/src/templates/theiaPlugins.json | jq -r '. | to_entries[] | " \(.value)"' | sed \
				-e 's/^[ \t]*//' \
				-e 's#.*/##'  \
				-e "s#^#codeready-workspaces-theia-rhel8-container:${CRW_VERSION}/#g"	\
		| sort -uV >> ${MANIFEST_FILE}

		# re-sort uniquely after adding more content
		cat ${MANIFEST_FILE} | sort -uV > "${MANIFEST_FILE}".2; mv "${MANIFEST_FILE}".2 "${MANIFEST_FILE}"
	cd ..
popd >/dev/null || exit
rm -f "${MANIFEST_FILE}.yarn" "${MANIFEST_FILE}.globalyarn" "${MANIFEST_FILE}.plugin-extensions"
rm -fr "$TMPDIR"

##################################

log "Short manifest is in file: ${MANIFEST_FILE}"
log "Long log is in file: ${LOG_FILE}"
log ""

##################################
