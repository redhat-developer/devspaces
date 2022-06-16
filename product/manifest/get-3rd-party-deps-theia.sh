#!/bin/bash

# script to generate a manifest of all the 3rd party deps not built in OSBS, but built in Jenkins or imported from upstream community.

JENKINS=https://main-jenkins-csb-crwqe.apps.ocp-c1.prod.psi.redhat.com/job/DS_CI/job

MIDSTM_BRANCH=""
SCRIPT_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
usage () 
{
    echo "Usage: $0 -b $(git rev-parse --abbrev-ref HEAD) -v 3.y.0"
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
  CSV_VERSION=$(curl -sSLo - https://raw.githubusercontent.com/redhat-developer/devspaces-operator/${MIDSTM_BRANCH}/manifests/devspaces.csv.yaml | yq -r .spec.version)
fi
DS_VERSION=$(curl -sSLo - https://raw.githubusercontent.com/redhat-developer/devspaces/${MIDSTM_BRANCH}/dependencies/VERSION)

EXCLUDE_FILES="e2e|kubernetes"
EXCLUDE_LINES="eclipse-che/che-theia|redhat-developer/devspaces/|redhat-developer/devspaces-theia|SHASUMS256.txt|CDN_PREFIX|cdn.stage.redhat.com|api.github.com|GITHUB_LIMIT|GITHUB_TOKEN|THEIA_GITHUB_REPO|.git$|.asc|/debian$|/debian/$|APKINDEX.tar.gz|get-pip|=http"
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
[[ "${MIDSTM_BRANCH}" == "devspaces-3-rhel-8" ]] && JOB_BRANCH="2.x" || JOB_BRANCH="${DS_VERSION}"
echo "Parsing ${JENKINS}/theia-sources_${JOB_BRANCH}/lastSuccessfulBuild/consoleText ..."
curl -sSL -o "${MANIFEST_FILE}".2 "${JENKINS}/theia-sources_${JOB_BRANCH}/lastSuccessfulBuild/consoleText"
CHE_THEIA_BRANCH=$(grep "echo SOURCE_BRANCH=" "${MANIFEST_FILE}".2 | sed -r -e "s#.+echo SOURCE_BRANCH=(.+)#\1#") # 7.yy.x
rm -f "${MANIFEST_FILE}.2"

if [[ -z $CHE_THEIA_BRANCH ]]; then 
	echo "[INFO] Could not obtain theia source branch from ${JENKINS}/theia-sources_${JOB_BRANCH}/lastSuccessfulBuild/consoleText - checking BUILD_PARAMS:"
	export $(curl -sSLo- https://raw.githubusercontent.com/redhat-developer/devspaces-theia/${MIDSTM_BRANCH}/BUILD_PARAMS | grep SOURCE_BRANCH | sed -r -e "s@SOURCE_BRANCH@CHE_THEIA_BRANCH@")
	if [[ -z $CHE_THEIA_BRANCH ]]; then
		echo "[ERROR] Could not compute CHE_THEIA_BRANCH from https://raw.githubusercontent.com/redhat-developer/devspaces-theia/${MIDSTM_BRANCH}/BUILD_PARAMS"
		exit 1
	fi
fi

TMPDIR=$(mktemp -d)
pushd "$TMPDIR" >/dev/null || exit
	if [[ -x ${SCRIPT_DIR}/../containerExtract.sh ]]; then
		cp ${SCRIPT_DIR}/../containerExtract.sh $TMPDIR/containerExtract.sh
	else
		curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/${MIDSTM_BRANCH}/product/containerExtract.sh
	fi
	chmod +x containerExtract.sh

	git clone --depth 1 --branch "${CHE_THEIA_BRANCH}" https://$GITHUB_TOKEN:x-oauth-basic@github.com/eclipse-che/che-theia.git 
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
				-e "s#^#devspaces-theia-rhel8-container:${DS_VERSION}/#g"	\
		| sort -uV > ${MANIFEST_FILE}.yarn

		podman pull quay.io/devspaces/theia-rhel8:${DS_VERSION}

		# copy plugin directories into the filesystem, in order to execute yarn commands to obtain yarn.lock file, and list dependencies from it
		"${TMPDIR}/containerExtract.sh" quay.io/devspaces/theia-rhel8:${DS_VERSION} --tar-flags default-theia-plugins/**
		find /tmp/quay.io-devspaces-theia-rhel8-${DS_VERSION}-* -path '*extension/node_modules' -exec sh -c "cd {}/.. && yarn --silent && yarn list --depth=0" \; >> ${MANIFEST_FILE}.plugin-extensions
		sed \
				-e '/Done in/d' \
				-e '/yarn list/d ' \
				-e 's/[├──└│]//g' \
				-e 's/^[ \t]*//' \
				-e 's/^@//' \
				-e "s/@/:/g" \
				-e "s#^#devspaces-theia-rhel8-container:${DS_VERSION}/#g"	\
		${MANIFEST_FILE}.plugin-extensions | sort -uV >> ${MANIFEST_FILE}
		
		echo >> ${MANIFEST_FILE}

		# collect global yarn dependencies, obtained from yarn.lock file in the theia-container yarn installation
		podman run --rm  --entrypoint /bin/sh "quay.io/devspaces/theia-rhel8:${DS_VERSION}" \
			-c "cat /usr/local/share/.config/yarn/global/yarn.lock" | grep -e 'version "' -B1 | \
			sed -r -e '/^--$/d' \
			-e 's/^"@//' > "${MANIFEST_FILE}.globalyarn"
		while IFS= read -r dependency
		do
			read -r version
			dependency=$(echo ${dependency} | tr -d '"' | cut -f1 -d"@")
			version=$(echo ${version} | cut -f2 -d" " | tr -d '"')
			echo "devspaces-theia-rhel8-container:${DS_VERSION}/${dependency}:${version}" >> "${MANIFEST_FILE}.yarn"
		done < "${MANIFEST_FILE}.globalyarn"
		
		cat ${MANIFEST_FILE}.yarn | sort -uV >> ${MANIFEST_FILE}
		echo >> ${MANIFEST_FILE}

		cat generator/src/templates/theiaPlugins.json | jq -r '. | to_entries[] | " \(.value)"' | sed \
				-e 's/^[ \t]*//' \
				-e 's#.*/##'  \
				-e "s#^#devspaces-theia-rhel8-container:${DS_VERSION}/#g"	\
		| sort -uV >> ${MANIFEST_FILE}

		# re-sort uniquely after adding more content
		cat ${MANIFEST_FILE} | sort -uV > "${MANIFEST_FILE}".2; mv "${MANIFEST_FILE}".2 "${MANIFEST_FILE}"
	cd ..
popd >/dev/null || exit
rm -f "${MANIFEST_FILE}.yarn" "${MANIFEST_FILE}.globalyarn" "${MANIFEST_FILE}.plugin-extensions"
rm -fr "$TMPDIR" /tmp/quay.io-devspaces-theia-rhel8-${DS_VERSION}-*

##################################

log "Short manifest is in file: ${MANIFEST_FILE}"
log "Long log is in file: ${LOG_FILE}"
log ""

##################################
