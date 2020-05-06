#!/bin/bash

# script to generate a manifest of all the maven dependencies used ot build upstream Che projects

# use x.y (not x.y.z) version
CRW_VERSION=2.1
CRW_TAG_OR_BRANCH=master

# use x.y.z version
CHE_VERSION=7.9.3

cd /tmp
MANIFEST_FILE=/tmp/manifest-mvn.txt

rm -fr ${MANIFEST_FILE} ${MANIFEST_FILE/.txt/-raw-unsorted.txt}

function mnf () {
	echo "$1" | tee -a ${MANIFEST_FILE}
}

function clone_and_generate_dep_tree () {
	cd /tmp
	GITREPO=$1
	GITTAG=$2
	rm -fr ${GITREPO##*/}
	# echo "$1 :: $2 ... "
	git clone -q ${GITREPO} ${GITREPO##*/} && cd ${GITREPO##*/} && git checkout -q ${GITTAG} && mvn dependency:tree > ${GITREPO##*/}_log.txt
	cat ${GITREPO##*/}_log.txt | egrep "\+\-|\\\-" | sed -e "s#.\+\ \(.\+\)#\1#g" -e "s#:\(compile\|provided\|test\|system\|runtime\)\$##g" -e "s#^\(org.eclipse.che\|org.apache.maven\).\+##g" \
		-e "s#\(.\+\):\(.\+\):jar:#\1_\2.jar:#g" -e "s#^#  codeready-workspaces-server-container:${CRW_VERSION}/#g" | sort | uniq >> ${MANIFEST_FILE/.txt/-raw-unsorted.txt}
	cd .. && rm -fr ${GITREPO##*/}
	mnf "codeready-workspaces-server-container:${CRW_VERSION}/${GITREPO##*//}:${GITTAG}"
}
echo "Generate a list of MVN dependencies from upstream Che & CRW product repos (~2 mins to run):"
clone_and_generate_dep_tree https://github.com/eclipse/che-dev 20 &
clone_and_generate_dep_tree https://github.com/eclipse/che-parent ${CHE_VERSION}
clone_and_generate_dep_tree https://github.com/eclipse/che ${CHE_VERSION} & 
clone_and_generate_dep_tree https://github.com/redhat-developer/codeready-workspaces-deprecated ${CRW_TAG_OR_BRANCH} & 
clone_and_generate_dep_tree https://github.com/redhat-developer/codeready-workspaces-theia ${CRW_TAG_OR_BRANCH} & 
clone_and_generate_dep_tree https://github.com/redhat-developer/codeready-workspaces-operator ${CRW_TAG_OR_BRANCH} & 
clone_and_generate_dep_tree https://github.com/redhat-developer/codeready-workspaces-chectl ${CRW_TAG_OR_BRANCH} & 
clone_and_generate_dep_tree https://github.com/redhat-developer/codeready-workspaces ${CRW_TAG_OR_BRANCH} & 
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
