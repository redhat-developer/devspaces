#!/bin/bash
#
# Copyright (c) 2019-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to tag the Che/CRW repos for a given release

if [[ ! $1 ]]; then
	echo "Usage: $0 version-to-tag"
	echo "Example: $0 2.1.1.GA"
	exit 1
else
	TAG="$1"
fi

# source branches to tag
pkgs_devel_branch=crw-2.2-rhel-8
# TODO is this branch still required for 2.2?
che_operator_branch=crw-2.2
crw_repos_branch=master 
# source branches to tag

mkdir -p /tmp/tmp-checkouts
cd /tmp/tmp-checkouts

for d in \
codeready-workspaces-operator  codeready-workspaces-operator-metadata \
codeready-workspaces \
\
codeready-workspaces-jwtproxy codeready-workspaces-machineexec \
codeready-workspaces-devfileregistry codeready-workspaces-pluginregistry \
codeready-workspaces-pluginbroker-metadata codeready-workspaces-pluginbroker-artifacts \
codeready-workspaces-imagepuller \
\
codeready-workspaces-plugin-kubernetes codeready-workspaces-plugin-openshift \
codeready-workspaces-plugin-java11 \
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

for d in che-operator; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone --depth 1 -b ${che_operator_branch} git@github.com:eclipse/${d}.git projects_${d}; fi
	cd projects_${d} && git checkout ${che_operator_branch} -q && git pull -q
	git tag ${TAG};	git push origin ${TAG}
	cd ..
done

for d in codeready-workspaces-operator; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone --depth 1 -b ${crw_repos_branch} git@github.com:redhat-developer/${d}.git projects_${d}; fi 
	cd projects_${d} && git checkout ${crw_repos_branch} -q && git pull -q

	# CRW-833 inject latest CSV files w/ latest digests
	rsync -aPr ../containers_codeready-workspaces-operator-metadata/controller-manifests/* ./controller-manifests/
	git add ./controller-manifests/
	git commit -s -m "[release] copy generated controller-manifests content back to codeready-workspaces-operator before tagging" ./controller-manifests/
	git push origin ${crw_repos_branch}
	git tag ${TAG}; git push origin ${TAG}
	cd ..
done

for d in codeready-workspaces codeready-workspaces-deprecated codeready-workspaces-chectl \
		 codeready-workspaces-theia codeready-workspaces-productization; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone --depth 1 -b ${crw_repos_branch} git@github.com:redhat-developer/${d}.git projects_${d}; fi 
	cd projects_${d} && git checkout ${crw_repos_branch} -q && git pull -q
	git tag ${TAG}; git push origin ${TAG}
	cd ..
done

# cleanup
# cd /tmp
echo "Temporary checkouts are in /tmp/tmp-checkouts"
# rm -fr /tmp/tmp-checkouts
