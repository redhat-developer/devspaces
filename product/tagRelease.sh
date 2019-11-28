#!/bin/bash
#
# script to tag the Che/CRW repos for a given release

if [[ ! $1 ]]; then
	echo "Usage: $0 version-to-tag"
	echo "Example: $0 2.0.0.GA"
	exit 1
else
	TAG="$1"
fi

mkdir -p /tmp/tmp-checkouts
cd /tmp/tmp-checkouts

pkgs_devel_branch=crw-2.0-rhel-8
for d in \
codeready-workspaces codeready-workspaces-operator \
codeready-workspaces-jwtproxy codeready-workspaces-machineexec \
codeready-workspaces-devfileregistry codeready-workspaces-pluginregistry \
codeready-workspaces-pluginbrokerinit codeready-workspaces-pluginbroker \
codeready-workspaces-plugin-kubernetes codeready-workspaces-plugin-openshift \
codeready-workspaces-theia codeready-workspaces-theia-endpoint \
codeready-workspaces-theia-dev codeready-workspaces-stacks-cpp \
codeready-workspaces-stacks-dotnet codeready-workspaces-stacks-golang \
codeready-workspaces-stacks-java codeready-workspaces-stacks-node \
codeready-workspaces-stacks-php codeready-workspaces-stacks-python \
; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone -b ${pkgs_devel_branch} ssh://nboldt@pkgs.devel.redhat.com/containers/${d} containers_${d}; fi
	cd containers_${d} && git checkout ${pkgs_devel_branch} -q && git pull -q
	git tag -a ${TAG} -m "${TAG}"; git push origin ${TAG}
	cd ..
done

che_operator_branch=crw-2.0
for d in che-operator; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone --depth 1 -b ${che_operator_branch} git@github.com:eclipse/${d}.git projects_${d}; fi
	cd projects_${d} && git checkout ${che_operator_branch} -q && git pull -q
	git tag ${TAG};	git push origin ${TAG}
	cd ..
done

crw_repos_branch=master 
for d in codeready-workspaces codeready-workspaces-deprecated \
		 codeready-workspaces-operator codeready-workspaces-chectl \
		 codeready-workspaces-theia codeready-workspaces-productization; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone --depth 1 -b ${crw_repos_branch} git@github.com:redhat-developer/${d}.git projects_${d}; fi 
	cd projects_${d} && git checkout ${crw_repos_branch} -q && git pull -q
	git tag ${TAG}; git push origin ${TAG}
	cd ..
done

# cleanup
# cd /tmp
# rm -fr /tmp/tmp-checkouts
