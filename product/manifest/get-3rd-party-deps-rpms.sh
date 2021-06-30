#!/bin/bash

# script to generate a manifest of all the rpms installed into the containers

MIDSTM_BRANCH=""
arches="x86_64" # for s390x & ppc64le, just override when fetching openj9 containers
allNVRs=""
MATCH=""
quiet=0

usage () {
	echo -e "
Usage:
NVR1 NVR2 ...   | list of NVRs to query. If omitted, generate list from ${candidateTag}
-b              | branch of redhat-developer/codeready-workspaces-operator, eg., crw-2.y-rhel-8
-v              | CSV version, eg., 2.y.0; if not set, will be computed from codeready-workspaces.csv.yaml using branch
-h,     --help  | show this help menu
-g \"regex\"      | if provided, grep resulting rpm logs for matching regex

Examples:
$0 codeready-workspaces-stacks-node-container-2.0-12.1552519049 codeready-workspaces-stacks-java-container

$0 stacks-dotnet -g \"/(libssh2|python|python-libs).x86_64\" # check one container for version of two rpms

$0 # to generate overall log for all latest NVRs
"
	exit 
}
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-h'|'--help') usage;;
    '-b')  MIDSTM_BRANCH="$2";     shift 2;;
    '-v')    CSV_VERSION="$2";     shift 2;;
    '-a'|'--arches') arches="$2";  shift 2;; 
    '-g')          MATCH="$2";     shift 2;;
    '-q')          quiet=1;        shift 1;;
    *)  allNVRs="${allNVRs} $1"; shift 1;;
  esac
done
if [[ ! ${MIDSTM_BRANCH} ]]; then usage; fi

candidateTag="${MIDSTM_BRANCH}-container-candidate"

if [[ ! ${CSV_VERSION} ]]; then 
  CSV_VERSION=$(curl -sSLo - https://raw.githubusercontent.com/redhat-developer/codeready-workspaces-operator/${MIDSTM_BRANCH}/manifests/codeready-workspaces.csv.yaml | yq -r .spec.version)
fi
CRW_VERSION=$(echo $CSV_VERSION | sed -r -e "s#([0-9]+\.[0-9]+)[^0-9]+.+#\1#") # trim the x.y part from the x.y.z

cd /tmp || exit
mkdir -p "${WORKSPACE}/${CSV_VERSION}/rpms"
MANIFEST_FILE="${WORKSPACE}/${CSV_VERSION}/rpms/manifest-rpms.txt"
MANIFEST_UNIQ_FILE="${WORKSPACE}/${CSV_VERSION}/rpms/manifest-rpms_uniq.txt"
LOG_FILE="${WORKSPACE}/${CSV_VERSION}/rpms/manifest-rpms_log.txt"
rm -fr "${MANIFEST_FILE}" "${LOG_FILE}"

function log () {
	if [[ $quiet -eq 0 ]]; then 
		echo "$1" | tee -a ${LOG_FILE}
	fi
}
function mnf () {
	echo "$1" | tee -a ${MANIFEST_FILE}
}
function bth () {
	echo "$1" >> ${MANIFEST_FILE}
	echo "$1" | tee -a ${LOG_FILE}
}

function loadNVRs() {
	pushd /tmp >/dev/null || exit
	curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/${MIDSTM_BRANCH}/product/getLatestImageTags.sh
	chmod +x getLatestImageTags.sh
	mnf "[INFO] Latest image list for ${MIDSTM_BRANCH}"
	/tmp/getLatestImageTags.sh -b ${MIDSTM_BRANCH} --nvr | tee /tmp/getLatestImageTags.sh.nvrs.txt
	loadNVRs_return="$(cat /tmp/getLatestImageTags.sh.nvrs.txt)"
	popd >/dev/null || exit
}

function loadNVRlog() {
	NVR="$1"
	MANIFEST_FILE2="$2"
	ARCH="$3"
	# shellcheck disable=SC2001
	URL=$(echo $NVR | sed -e "s#\(.\+\(-container\|-rhel8\)\)-\([0-9.]\+\)-\([0-9.]\+\)#http://download.eng.bos.redhat.com/brewroot/packages/\1/\3/\4/data/logs/${ARCH}-build.log#")
	# log ""
	log "   ${URL}"

	input=/tmp/${NVR}.log
	curl -s $URL -o $input
	collecting=0
	while IFS= read -r line
	do
		# echo "[$collecting] $line"
		if [[ $line == "Installed Packages" ]]; then # start collecting lines
			collecting=1
			continue
		elif [[ $line == "End Of Installed Packages" ]]; then
			# echo "${NVR}    $line" >> ${MANIFEST_FILE}
			if [[ $quiet -eq 0 ]]; then echo ""; else echo "   $NVR" | tee -a ${LOG_FILE}; fi
			break
		fi
		if [[ $collecting -eq 1 ]] && [[ $line ]]; then
			# rh-maven35-maven-lib.noarch                               1:3.5.0-4.3.el7                @rhel-server-rhscl-7-rpms          
			# NVR = codeready-workspaces-stacks-python-container-2.0-8 (NVR notation)
			# want  codeready-workspaces-stacks-python-container:2.0-8 (prod:version notation)
			# shellcheck disable=SC2001,SC2086
			echo "${NVR/-container-/-container:}/$(echo $line | sed -e "s#\(.\+\)[\ \t]\+\(.\+\)[\ \t]\+\@.\+#\1-\2#g")" >> ${MANIFEST_FILE}
			# shellcheck disable=SC2001,SC2086
			echo "${NVR/-container-/-container:}/$(echo $line | sed -e "s#\(.\+\)[\ \t]\+\(.\+\)[\ \t]\+\@.\+#\1-\2#g")" >> ${MANIFEST_FILE2}
		fi
	done < "$input"
	rm -f $input
	if [[ $quiet -eq 0 ]]; then mnf ""; else echo "" >> ${MANIFEST_FILE}; fi
}

if [[ ${allNVRs} == "" ]]; then
	log "[INFO] Compute list of latest ${candidateTag} NVRs ... ";
	loadNVRs; allNVRs="${allNVRs} ${loadNVRs_return}"
	log ""
fi
log "[INFO] NVRs to query for installed rpms:"
for NVR in ${allNVRs}; do
	log "   $NVR"
done

log ""

# allNVRs=codeready-workspaces-stacks-python-container-2.0-6
log "[INFO] Brew logs:"
for NVR in ${allNVRs}; do
	MANIFEST_FILE2="${WORKSPACE}/${CSV_VERSION}/rpms/manifest-rpms-${NVR}.txt"
	rm -fr ${MANIFEST_FILE2}
	for arch in ${arches}; do
		if [[ ${NVR} == *"openj9"* ]]; then arch="s390x"; fi # z and p only
		if [[ ${NVR} == *"dotnet"* ]]; then arch="x86_64"; fi # x only
		loadNVRlog $NVR ${MANIFEST_FILE2} ${arch}
	done
done

if [[ $quiet -eq 0 ]]; then
	log "" 
	log "[INFO] NVR build IDs:" 
	for NVR in ${allNVRs}; do 
		buildID=$(brew buildinfo $NVR | grep BUILD | sed -e "s#BUILD: $NVR \[\(.\+\)\]#\1#")
		log "   $NVR [${buildID}] - https://brewweb.engineering.redhat.com/brew/buildinfo?buildID=${buildID}"
	done
fi

##################################

# get uniq list of RPMs
cat ${WORKSPACE}/${CSV_VERSION}/rpms/manifest-rpms-codeready-workspaces-* | sed -r -e "s#.+:${CRW_VERSION}-[0-9.]+/# #g" | sort | uniq > ${MANIFEST_UNIQ_FILE}

##################################

echo "" | tee -a ${LOG_FILE}
echo "[INFO] Overall RPM manifest is in file: ${MANIFEST_FILE}" | tee -a ${LOG_FILE}
echo "[INFO] Unique RPM manifest is in file: ${MANIFEST_UNIQ_FILE}" | tee -a ${LOG_FILE}
echo "[INFO] Long RPM log is in file: ${LOG_FILE}" | tee -a ${LOG_FILE}
echo "" | tee -a ${LOG_FILE}
echo "[INFO] Individual RPM manifests:" | tee -a ${LOG_FILE}
for NVR in ${allNVRs}; do 
	echo "* ${WORKSPACE}/${CSV_VERSION}/rpms/manifest-rpms-${NVR}.txt" | tee -a ${LOG_FILE}
	if [[ ${MATCH} ]]; then
		egrep "${MATCH}" ${WORKSPACE}/${CSV_VERSION}/rpms/manifest-rpms-${NVR}.txt | sed -e "s#${NVR/container-/container:}/#    #" | tee -a ${LOG_FILE}
	fi
done
echo "" | tee -a ${LOG_FILE}

##################################
