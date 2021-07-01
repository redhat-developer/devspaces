#!/bin/bash

# script to generate a manifest of all the 3rd party deps not built in OSBS, but built in Jenkins or imported from upstream community.

JENKINS=https://main-jenkins-csb-crwqe.apps.ocp4.prod.psi.redhat.com/job/CRW_CI/job

MIDSTM_BRANCH=""
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
mkdir -p "${WORKSPACE}/${CSV_VERSION}/theia"
MANIFEST_FILE="${WORKSPACE}/${CSV_VERSION}/theia/manifest-theia.txt"
LOG_FILE="${WORKSPACE}/${CSV_VERSION}/theia/manifest-theia_log.txt"

function log () {
	echo "$1" | tee -a "${LOG_FILE}"
}

rm -f "${MANIFEST_FILE}" "${MANIFEST_FILE}".2 "${LOG_FILE}"
echo "Parsing ${JENKINS}/crw-theia-sources_${CRW_VERSION}/lastSuccessfulBuild/consoleText ..."
curl -sSL -o "${MANIFEST_FILE}" "${JENKINS}/crw-theia-sources_${CRW_VERSION}/lastSuccessfulBuild/consoleText"
CHE_THEIA_BRANCH=$(grep "build.include" "${MANIFEST_FILE}" | sort -u | grep curl | sed -r -e "s#.+che-theia/(.+)/build.include#\1#") # 7.yy.x

# shellcheck disable=SC2013 disable=SC2002
for d in $(cat "${MANIFEST_FILE}" | grep -E "https://|http://"); do 
	echo "$d" | grep -E "https://|http://" | tr -d "\"'()" | sed -r -e "s#[.:]\$##" >> "${MANIFEST_FILE}".2
	echo -n "."
done
echo ""
# shellcheck disable=SC2002
cat "${MANIFEST_FILE}".2 | uniq | sort | grep -E -v "${EXCLUDE_LINES}" | uniq | sort > "${MANIFEST_FILE}".3
echo "# URLs found in build log" > "${MANIFEST_FILE}".2
cat "${MANIFEST_FILE}".2 "${MANIFEST_FILE}".3 > "${MANIFEST_FILE}"
rm -f "${MANIFEST_FILE}".2 "${MANIFEST_FILE}".3

TMPDIR=$(mktemp -d)
pushd "$TMPDIR" >/dev/null || exit
	git clone https://$GITHUB_TOKEN:x-oauth-basic@github.com/eclipse-che/che-theia.git 
	cd che-theia || exit
		git config --global push.default matching
		git config --global hub.protocol https
		git fetch || true
		git checkout --track "origin/${CHE_THEIA_BRANCH}"
		git pull origin "${CHE_THEIA_BRANCH}"
		# shellcheck disable=SC2129
		echo "" >> "${MANIFEST_FILE}"
		# get yarn deps
		echo "# yarn deps" >> "${MANIFEST_FILE}"
		yarn list --depth=0 >> "${MANIFEST_FILE}"
	cd ..
popd >/dev/null || exit
rm -fr "$TMPDIR"

##################################

log "Short manifest is in file: ${MANIFEST_FILE}"
log "Long log is in file: ${LOG_FILE}"
log ""

##################################
