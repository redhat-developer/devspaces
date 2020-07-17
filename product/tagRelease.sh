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

set -ex

# defaults
crw_repos_branch=master 
pkgs_devel_branch=crw-2.2-rhel-8

if [[ $# -lt 4 ]]; then
	echo "Usage: $0 -t CRW_TAG -o CHE_OPERATOR_BRANCH [-gh CRW_GH_BRANCH] [-pd PKGS_DEVEL_BRANCH]"
	echo "Example: $0 -t 2.2.0.GA -o 7.14.x -gh master -pd crw-2.2-rhel-8"
	exit 1
fi

# commandline args
for key in "$@"; do
  case $key in
    '-t') CRW_TAG="$2"; shift 0;;
    '-o') che_operator_branch="$2"; shift 0;;
    '-gh') crw_repos_branch="$2"; shift 0;;
    '-pd') pkgs_devel_branch="$2"; shift 0;;
  esac
  shift 1
done

rm -fr /tmp/tmp-checkouts || true
mkdir -p /tmp/tmp-checkouts
cd /tmp/tmp-checkouts

for d in \
codeready-workspaces-operator  codeready-workspaces-operator-metadata \
codeready-workspaces codeready-workspaces-imagepuller \
codeready-workspaces-jwtproxy codeready-workspaces-machineexec \
codeready-workspaces-devfileregistry codeready-workspaces-pluginregistry \
codeready-workspaces-pluginbroker-metadata codeready-workspaces-pluginbroker-artifacts \
\
codeready-workspaces-theia codeready-workspaces-theia-endpoint \
codeready-workspaces-theia-dev \
\
codeready-workspaces-plugin-java11 codeready-workspaces-plugin-java8 \
codeready-workspaces-plugin-kubernetes codeready-workspaces-plugin-openshift \
codeready-workspaces-stacks-cpp codeready-workspaces-stacks-dotnet \
codeready-workspaces-stacks-golang codeready-workspaces-stacks-php  \
; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone -b ${pkgs_devel_branch} ssh://nboldt@pkgs.devel.redhat.com/containers/${d} containers_${d}; fi
	cd containers_${d} && git checkout ${pkgs_devel_branch} -q && git pull -q
	git tag -a ${CRW_TAG} -m "${CRW_TAG}"; git push origin ${CRW_TAG}
	cd ..
done

for d in che-operator; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone --depth 1 -b ${che_operator_branch} git@github.com:eclipse/${d}.git projects_${d}; fi
	cd projects_${d} && git checkout ${che_operator_branch} -q && git pull -q
	git tag ${CRW_TAG};	git push origin ${CRW_TAG}
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
	git tag ${CRW_TAG}; git push origin ${CRW_TAG}
	cd ..
done

for d in codeready-workspaces codeready-workspaces-deprecated codeready-workspaces-chectl \
		 codeready-workspaces-theia codeready-workspaces-productization; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone --depth 1 -b ${crw_repos_branch} git@github.com:redhat-developer/${d}.git projects_${d}; fi 
	cd projects_${d} && git checkout ${crw_repos_branch} -q && git pull -q
	git tag ${CRW_TAG}; git push origin ${CRW_TAG}
	cd ..
done

# cleanup
# cd /tmp
echo "Temporary checkouts are in /tmp/tmp-checkouts"
# rm -fr /tmp/tmp-checkouts
