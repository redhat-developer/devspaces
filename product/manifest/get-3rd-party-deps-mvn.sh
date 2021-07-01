#!/bin/bash

# script to generate a manifest of all the maven dependencies used to build upstream Che projects

MIDSTM_BRANCH=""
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
CRW_TAG_OR_BRANCH=${MIDSTM_BRANCH}

# load SOURCE_BRANCH from theia BUILD_PARAMS
for d in $(curl -sSLo - https://raw.githubusercontent.com/redhat-developer/codeready-workspaces-theia/${MIDSTM_BRANCH}/BUILD_PARAMS); do
	export $d
done

# use x.y.z version, eg., 7.30.2
CHE_VERSION=$(curl -sSLo - https://raw.githubusercontent.com/eclipse-che/che-server/${SOURCE_BRANCH}/pom.xml | grep "<che.version>" | sed -r -e "s#.*<che.version>(.+)</che.version>.*#\1#")
if [[ $CHE_VERSION =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)-SNAPSHOT ]]; then # reduce the z digit, remove the snapshot suffix
  XX=${BASH_REMATCH[1]}
  YY=${BASH_REMATCH[2]}
  ZZ=${BASH_REMATCH[3]}; (( ZZ=ZZ-1 )); if [[ ZZ -lt 0 ]]; then ZZ=0; fi
  CHE_VERSION="${XX}.${YY}.${ZZ}"
fi
# echo "[DEBUG] CHE_VERSION = $CHE_VERSION"

# use x.y.z version, eg., 7.15.0
CHE_PARENT_VERSION=$(curl -sSLo - https://raw.githubusercontent.com/eclipse-che/che-server/${SOURCE_BRANCH}/pom.xml | \
   grep -A1 "<groupId>org.eclipse.che.parent</groupId>" | tail -1 | sed -r -e "s#.*<version>(.+)</version>.*#\1#")

cd /tmp || exit
mkdir -p ${WORKSPACE}/${CSV_VERSION}/mvn
MANIFEST_FILE="${WORKSPACE}/${CSV_VERSION}/mvn/manifest-mvn.txt"

rm -fr ${MANIFEST_FILE} ${MANIFEST_FILE/.txt/-raw-unsorted.txt}

function mnf () {
	echo "$1" | tee -a ${MANIFEST_FILE}
}

function clone_and_generate_dep_tree () {
	cd /tmp || exit
	GITREPO=$1
	GITTAG=$2
	rm -fr ${GITREPO##*/}
	# echo "$1 :: $2 ... "
	git clone -q ${GITREPO} ${GITREPO##*/} && cd ${GITREPO##*/} && git checkout -q ${GITTAG} && \
	mvn dependency:tree | tee ${WORKSPACE}/${CSV_VERSION}/mvn/${GITREPO##*/}_log.txt
	cat ${WORKSPACE}/${CSV_VERSION}/mvn/${GITREPO##*/}_log.txt | grep -E "\+\-|\\\-" \
		| sed \
			-e "s#.\+\ \(.\+\)#\1#g" \
			-e "s#:\(compile\|provided\|test\|system\|runtime\)\$##g" \
			-e "s#^\(org.eclipse.che\|org.apache.maven\).\+##g" \
			-e "s#\(.\+\):\(.\+\):jar:#\1_\2.jar:#g" \
			-e "s#^#  codeready-workspaces-server-container:${CRW_VERSION}/#g" \
		| sort | uniq >> ${MANIFEST_FILE/.txt/-raw-unsorted.txt}
	cd .. && rm -fr ${GITREPO##*/}
	mnf "codeready-workspaces-server-container:${CRW_VERSION}/${GITREPO##*//}:${GITTAG}"
}
echo "Generate a list of MVN dependencies from upstream Che repos (~2 mins to run):"
clone_and_generate_dep_tree https://github.com/eclipse/che-dev 20 &
clone_and_generate_dep_tree https://github.com/eclipse/che-parent ${CHE_PARENT_VERSION}
clone_and_generate_dep_tree https://github.com/eclipse-che/che-server ${CHE_VERSION} & 
wait

echo "Sort and dedupe deps across the repos:"
cat ${MANIFEST_FILE/.txt/-raw-unsorted.txt} | sort | uniq >> ${MANIFEST_FILE}
echo "" >> ${MANIFEST_FILE}

##################################

echo ""
echo "Short MVN manifest is in file: ${MANIFEST_FILE}"
echo "Raw MVN manifest is in file: ${MANIFEST_FILE/.txt/-raw-unsorted.txt}"
echo ""

##################################
