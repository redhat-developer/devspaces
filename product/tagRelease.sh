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
crw_repos_branch=crw-2.5-rhel-8
pkgs_devel_branch=crw-2.5-rhel-8
pduser=crw-build

if [[ $# -lt 4 ]]; then
	echo "Usage: $0 -t CRW_TAG -gh CRW_GH_BRANCH -ghtoken GITHUB_TOKEN -pd PKGS_DEVEL_BRANCH -pduser kerberos_user"
	echo "Example: $0 -t 2.5.0 -gh crw-2.5-rhel-8 -ghtoken \$GITHUB_TOKEN -pd crw-2.5-rhel-8 -pduser crw-build"
	exit 1
fi

# commandline args
for key in "$@"; do
  case $key in
    '-t') CRW_TAG="$2"; shift 0;;
    '-gh') crw_repos_branch="$2"; shift 0;;
    '-ghtoken') GITHUB_TOKEN="$2"; shift 0;;
    '-pd') pkgs_devel_branch="$2"; shift 0;;
    '-pduser') pduser="$2"; shift 0;;
  esac
  shift 1
done

rm -fr /tmp/tmp-checkouts || true
mkdir -p /tmp/tmp-checkouts
cd /tmp/tmp-checkouts

for d in \
codeready-workspaces-operator  codeready-workspaces-operator-metadata \
codeready-workspaces           codeready-workspaces-imagepuller \
codeready-workspaces-jwtproxy  codeready-workspaces-machineexec \
\
codeready-workspaces-devfileregistry  codeready-workspaces-pluginbroker-metadata \
codeready-workspaces-pluginregistry   codeready-workspaces-pluginbroker-artifacts \
\
codeready-workspaces-theia codeready-workspaces-theia-endpoint codeready-workspaces-theia-dev \
\
codeready-workspaces-plugin-java8        codeready-workspaces-plugin-java11 \
codeready-workspaces-plugin-java8-openj9 codeready-workspaces-plugin-java11-openj9 \
\
codeready-workspaces-plugin-kubernetes   codeready-workspaces-plugin-openshift \
\
codeready-workspaces-stacks-cpp          codeready-workspaces-stacks-dotnet \
codeready-workspaces-stacks-golang       codeready-workspaces-stacks-php  \
; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone -b ${pkgs_devel_branch} ssh://${pduser}@pkgs.devel.redhat.com/containers/${d} containers_${d}; fi
	cd containers_${d}
	git config user.email crw-build@REDHAT.COM
	git config user.name "CRW Build"
	git config --global push.default matching

	git checkout ${pkgs_devel_branch} -q
	git pull -q

	git tag -a ${CRW_TAG} -m "${CRW_TAG}" || true
	git push origin ${CRW_TAG} || true
	cd ..
done

for d in codeready-workspaces-operator; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone --depth 1 -b ${crw_repos_branch} git@github.com:redhat-developer/${d}.git projects_${d}; fi 
	cd projects_${d}
	export GITHUB_TOKEN="${GITHUB_TOKEN}"
	git config user.email "nickboldt+devstudio-release@gmail.com"
	git config user.name "Red Hat Devstudio Release Bot"
	git config --global push.default matching
	git config --global hub.protocol https
	git remote set-url origin https://${GITHUB_TOKEN}:x-oauth-basic@github.com/redhat-developer/${d}.git

	git checkout --track origin/${crw_repos_branch} -q || true
	git pull -q

	# CRW-833 inject latest CSV files w/ latest digests
	rsync -aPr ../containers_codeready-workspaces-operator-metadata/controller-manifests/* ./controller-manifests/
	git add ./controller-manifests/
	git commit -s -m "[release] copy generated controller-manifests content back to codeready-workspaces-operator before tagging" ./controller-manifests/ || true
	git push origin ${crw_repos_branch} || true

	git tag ${CRW_TAG} || true
	git push origin ${CRW_TAG} || true
	cd ..
done

for d in codeready-workspaces codeready-workspaces-deprecated codeready-workspaces-chectl \
		 codeready-workspaces-theia codeready-workspaces-productization; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone --depth 1 -b ${crw_repos_branch} git@github.com:redhat-developer/${d}.git projects_${d}; fi 
	cd projects_${d}
	export GITHUB_TOKEN="${GITHUB_TOKEN}"
	git config user.email "nickboldt+devstudio-release@gmail.com"
	git config user.name "Red Hat Devstudio Release Bot"
	git config --global push.default matching
	git config --global hub.protocol https
	git remote set-url origin https://${GITHUB_TOKEN}:x-oauth-basic@github.com/redhat-developer/${d}.git

	git checkout --track origin/${crw_repos_branch} -q || true
	git pull -q

	git tag ${CRW_TAG} || true
	git push origin ${CRW_TAG} || true
	cd ..
done

# cleanup
# cd /tmp
echo "Temporary checkouts are in /tmp/tmp-checkouts"
# rm -fr /tmp/tmp-checkouts