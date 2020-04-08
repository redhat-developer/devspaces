#!/bin/bash

# script to generate a manifest of all the 3rd party deps not built in OSBS, but built in Jenkins or imported from upstream community.

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT"); # echo $SCRIPTPATH

EXCLUDE_FILES="e2e|kubernetes"
EXCLUDE_LINES="api.github.com|GITHUB_LIMIT|GITHUB_TOKEN|THEIA_GITHUB_REPO|.git$|.asc|/debian$|/debian/$|APKINDEX.tar.gz|get-pip|=http"
EXCLUDE_LINES2="che:theia"

cd /tmp

MANIFEST_FILE=/tmp/manifest_theia.txt
LOG_FILE=/tmp/manifest_theia_log.txt

function log () {
	echo "$1" | tee -a ${LOG_FILE}
}

rm -f ${MANIFEST_FILE} ${MANIFEST_FILE}.2 ${MANIFEST_FILE}.3 ${LOG_FILE}
curl -sSL -o ${MANIFEST_FILE} https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/view/CRW_CI/view/Pipelines/job/crw-theia_master/lastSuccessfulBuild/consoleText
for d in $(cat ${MANIFEST_FILE} | egrep "https://|http://"); do 
	echo $d | egrep "https://|http://" >> ${MANIFEST_FILE}.2
	echo -n "."
done
echo ""
cat ${MANIFEST_FILE}.2 | uniq | sort | egrep -v "${EXCLUDE_LINES}" > ${MANIFEST_FILE}
cat ${MANIFEST_FILE} | uniq | sort > ${MANIFEST_FILE}.2
cat ${MANIFEST_FILE}.2 | uniq | sort > ${MANIFEST_FILE} 

# TODO get brew builds' logs too

if [[ ! -d che-theia ]]; then 
	git clone git@github.com:eclipse/che-theia.git
else
	cd che-theia; git pull origin master; cd ..
fi

Dockerfiles="$(find che-theia -name Dockerfile | egrep -v "${EXCLUDE_FILES}")"
for df in $Dockerfiles; do
	echo "== $df ==" | tee -a ${LOG_FILE}
	for line in $(cat ${MANIFEST_FILE}) openjdk " python" "Python-" "pip install"; do
		grep "$line" $df | egrep -v "${EXCLUDE_LINES2}" | tee -a ${LOG_FILE}
	done
	echo "" | tee -a ${LOG_FILE}
done

##################################

log "Short manifest is in file: ${MANIFEST_FILE}"
log "Long log is in file: ${LOG_FILE}"
log ""

##################################
