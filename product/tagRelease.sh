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

# defaults
crw_repos_branch=crw-2.5-rhel-8
pkgs_devel_branch=crw-2.5-rhel-8
pduser=crw-build
SOURCE_BRANCH="" # normally, use this script to create tags, not branches

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")

if [[ $# -lt 4 ]]; then
	echo "
To create tags:
  $0 -t CRW_TAG -gh CRW_GH_BRANCH -ghtoken GITHUB_TOKEN -pd PKGS_DEVEL_BRANCH -pduser kerberos_user
Example: 
  $0 -t 2.5.0 -gh crw-2.5-rhel-8 -ghtoken \$GITHUB_TOKEN -pd crw-2.5-rhel-8 -pduser crw-build

To create branches:
  $0 --branchfrom PREVIOUS_CRW_GH_BRANCH -gh NEW_CRW_GH_BRANCH -ghtoken GITHUB_TOKEN
Example: 
  $0 --branchfrom crw-2.5-rhel-8 -gh crw-2.6-rhel-8 -ghtoken \$GITHUB_TOKEN
"
	exit 1
fi

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--branchfrom') SOURCE_BRANCH="$2"; shift 1;; # this flag will create branches instead of using branches to create tags
    '-t') CRW_TAG="$2"; shift 1;;
    '-gh') crw_repos_branch="$2"; shift 1;;
    '-ghtoken') GITHUB_TOKEN="$2"; shift 1;;
    '-pd') pkgs_devel_branch="$2"; shift 1;;
    '-pduser') pduser="$2"; shift 1;;
  esac
  shift 1
done

rm -fr /tmp/tmp-checkouts || true
mkdir -p /tmp/tmp-checkouts
cd /tmp/tmp-checkouts

set -ex

if [[ -z ${SOURCE_BRANCH} ]]; then 
	for d in \
	codeready-workspaces-configbump \
	codeready-workspaces-operator \
	codeready-workspaces-operator-metadata \
	codeready-workspaces-devfileregistry \
	codeready-workspaces-imagepuller \
	\
	codeready-workspaces-jwtproxy \
	codeready-workspaces-machineexec \
	codeready-workspaces-pluginbroker-artifacts \
	codeready-workspaces-pluginbroker-metadata \
	codeready-workspaces-plugin-intellij \
	\
	codeready-workspaces-plugin-java11-openj9 \
	codeready-workspaces-plugin-java11  \
	codeready-workspaces-plugin-java8-openj9 \
	codeready-workspaces-plugin-java8 \
	codeready-workspaces-plugin-kubernetes \
	\
	codeready-workspaces-plugin-openshift \
	codeready-workspaces-pluginregistry \
	codeready-workspaces \
	codeready-workspaces-stacks-cpp \
	codeready-workspaces-stacks-dotnet \
	\
	codeready-workspaces-stacks-golang \
	codeready-workspaces-stacks-php \
	codeready-workspaces-theia-dev \
	codeready-workspaces-theia-endpoint \
	codeready-workspaces-theia \
	\
	codeready-workspaces-traefik \
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

fi

for d in \
codeready-workspaces \
codeready-workspaces-chectl \
codeready-workspaces-deprecated \
codeready-workspaces-images \
codeready-workspaces-operator \
codeready-workspaces-productization \
codeready-workspaces-theia \
; do
	echo; echo "== $d =="
	if [[ ${SOURCE_BRANCH} ]]; then clone_branch=${SOURCE_BRANCH}; else clone_branch=${crw_repos_branch}; fi
	if [[ ! -d ${d} ]]; then git clone --depth 1 -b ${clone_branch} git@github.com:redhat-developer/${d}.git projects_${d}; fi
	cd projects_${d}
	export GITHUB_TOKEN="${GITHUB_TOKEN}"
	git config user.email "nickboldt+devstudio-release@gmail.com"
	git config user.name "Red Hat Devstudio Release Bot"
	git config --global push.default matching
	git config --global hub.protocol https
	git remote set-url origin https://${GITHUB_TOKEN}:x-oauth-basic@github.com/redhat-developer/${d}.git

	git checkout --track origin/${clone_branch} -q || true
	git pull -q
	if [[ ${SOURCE_BRANCH} ]]; then # push a new branch
		git branch ${crw_repos_branch} || true
		git push origin ${crw_repos_branch} || true
	else # for operator, inject latest CSV files w/ latest digests (CRW-833)
		if [[ $d == "codeready-workspaces-operator" ]]; then
			# CRW-1386 OLD WAY, end up with internal repo refs in the published CSV
			# rsync -aPr ../containers_codeready-workspaces-operator-metadata/manifests/* ./manifests/

			# CRW-1386 new way - use containerExtract.sh to get the live, published operator-metadata image and copy the manifests/ folder from there
			rm -fr /tmp/registry.redhat.io-codeready-workspaces-crw-2-rhel8-operator-metadata-2.5*
			"${SCRIPTPATH}"/containerExtract.sh registry.redhat.io/codeready-workspaces/crw-2-rhel8-operator-metadata:2.5
			rsync -aPr /tmp/registry.redhat.io-codeready-workspaces-crw-2-rhel8-operator-metadata-2.5*/manifests/* ./manifests/

			git add ./manifests/
			git commit -s -m "[release] copy generated manifests/ content back to codeready-workspaces-operator before tagging" ./manifests/ || true
			git push origin ${crw_repos_branch} || true
		fi
		# then push new tag
		git tag ${CRW_TAG} || true
		git push origin ${CRW_TAG} || true
	fi
	cd ..
done

# cleanup
# cd /tmp
echo "Temporary checkouts are in /tmp/tmp-checkouts"
# rm -fr /tmp/tmp-checkouts