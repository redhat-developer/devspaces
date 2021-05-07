#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to tag the Che/CRW repos for a given release

# defaults
# try to compute branches from currently checked out branch; else fall back to hard coded value
crw_repos_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ $crw_repos_branch != "crw-2."*"-rhel-8" ]]; then
	crw_repos_branch="crw-2.8-rhel-8"
fi
pkgs_devel_branch=${crw_repos_branch}

pduser=crw-build
SOURCE_BRANCH="" # normally, use this script to create tags, not branches

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")
CLEAN="false" #  if set true, delete existing folders and do fresh checkouts

if [[ $# -lt 4 ]]; then
	echo "
To create tags (and push updated CSV content into operator-metadata repo):
  $0 -v CSV_VERSION -t CRW_VERSION -gh CRW_GH_BRANCH -ghtoken GITHUB_TOKEN -pd PKGS_DEVEL_BRANCH -pduser kerberos_user
Example: 
  $0 -v 2.y.0 -t 2.y -gh ${crw_repos_branch} -ghtoken \$GITHUB_TOKEN -pd ${pkgs_devel_branch} -pduser crw-build

To create branches:
  $0 --branchfrom PREVIOUS_CRW_GH_BRANCH -gh NEW_CRW_GH_BRANCH -ghtoken GITHUB_TOKEN
Example: 
  $0 --branchfrom crw-2-rhel-8 -gh ${crw_repos_branch} -ghtoken \$GITHUB_TOKEN
"
	exit 1
fi

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--branchfrom') SOURCE_BRANCH="$2"; shift 1;; # this flag will create branches instead of using branches to create tags
    '-v') CSV_VERSION="$2"; shift 1;; # 2.y.0
    '-t') CRW_VERSION="$2"; shift 1;; # 2.y # used to get released metadata container's CSV contents
    '-gh') crw_repos_branch="$2"; shift 1;;
    '-ghtoken') GITHUB_TOKEN="$2"; shift 1;;
    '-pd') pkgs_devel_branch="$2"; shift 1;;
    '-pduser') pduser="$2"; shift 1;;
	'--clean') CLEAN="true"; shift 0;; # if set true, delete existing folders and do fresh checkouts
  esac
  shift 1
done

if [[ ! ${CRW_VERSION} ]]; then
  CRW_VERSION=${CSV_VERSION%.*} # given 2.y.0, want 2.y
fi

if [[ ${CLEAN} == "true" ]]; then 
	rm -fr /tmp/tmp-checkouts || true
fi

mkdir -p /tmp/tmp-checkouts
cd /tmp/tmp-checkouts

set -ex

# tag pkgs.devel repos only (branches are created by SPMM ticket, eg., https://projects.engineering.redhat.com/browse/SPMM-2517)
if [[ ${pkgs_devel_branch} ]] && [[ ${CSV_VERSION} ]]; then 
	for d in \
	codeready-workspaces-configbump \
	codeready-workspaces-operator \
	codeready-workspaces-operator-metadata \
	codeready-workspaces-dashboard \
	codeready-workspaces-devfileregistry \
	\
	codeready-workspaces-devworkspace-controller \
	codeready-workspaces-devworkspace \
	codeready-workspaces-imagepuller \
	codeready-workspaces-jwtproxy \
	codeready-workspaces-machineexec \
	\
	codeready-workspaces-pluginbroker-artifacts \
	codeready-workspaces-pluginbroker-metadata \
	codeready-workspaces-plugin-java11-openj9 \
	codeready-workspaces-plugin-java11 \
	codeready-workspaces-plugin-java8-openj9 \
	\
	codeready-workspaces-plugin-java8 \
	codeready-workspaces-plugin-kubernetes \
	codeready-workspaces-plugin-openshift \
	codeready-workspaces-pluginregistry \
	codeready-workspaces \
	\
	codeready-workspaces-stacks-cpp \
	codeready-workspaces-stacks-dotnet \
	codeready-workspaces-stacks-golang \
	codeready-workspaces-stacks-php \
	codeready-workspaces-theia-dev \
	\
	codeready-workspaces-theia-endpoint \
	codeready-workspaces-theia \
	codeready-workspaces-traefik \
	; do
		echo; echo "== $d =="
		if [[ ! -d /tmp/tmp-checkouts/containers_${d} ]]; then
			git clone -b ${pkgs_devel_branch} ssh://${pduser}@pkgs.devel.redhat.com/containers/${d} containers_${d}
			pushd /tmp/tmp-checkouts/containers_${d} >/dev/null || exit 1
				export KRB5CCNAME=/var/tmp/${pduser}_ccache
				git config user.email ${pduser}@REDHAT.COM
				git config user.name "CRW Build"
				git config --global push.default matching

				git checkout --track origin/${pkgs_devel_branch} -q || true
				git pull -q
			popd >/dev/null || exit 1
		fi
		pushd /tmp/tmp-checkouts/containers_${d} >/dev/null || exit 1
			# push new tag (no op if already exists)
			git tag -a ${CSV_VERSION} -m "${CSV_VERSION}" || true
			git push origin ${CSV_VERSION} || true
		popd >/dev/null || exit 1
	done
fi

for d in \
codeready-workspaces \
codeready-workspaces-chectl \
codeready-workspaces-deprecated \
codeready-workspaces-images \
codeready-workspaces-operator \
codeready-workspaces-theia \
; do
	echo; echo "== $d =="
	if [[ ${SOURCE_BRANCH} ]]; then clone_branch=${SOURCE_BRANCH}; else clone_branch=${crw_repos_branch}; fi
	if [[ ! -d /tmp/tmp-checkouts/projects_${d} ]]; then
		git clone --depth 1 -b ${clone_branch} git@github.com:redhat-developer/${d}.git projects_${d}
		pushd /tmp/tmp-checkouts/projects_${d} >/dev/null || exit 1
			export GITHUB_TOKEN="${GITHUB_TOKEN}"
			git config user.email "nickboldt+devstudio-release@gmail.com"
			git config user.name "Red Hat Devstudio Release Bot"
			git config --global push.default matching
			git config --global hub.protocol https
			git remote set-url origin https://${GITHUB_TOKEN}:x-oauth-basic@github.com/redhat-developer/${d}.git

			git checkout --track origin/${clone_branch} -q || true
			git pull -q
		popd >/dev/null || exit 1
	fi
	pushd /tmp/tmp-checkouts/projects_${d} >/dev/null || exit 1
	if [[ ${SOURCE_BRANCH} ]]; then # push a new branch (or no-op if exists)
		git branch ${crw_repos_branch} || true
		git push origin ${crw_repos_branch} || true
	fi
	if [[ $CSV_VERSION ]]; then # push a new tag (or no-op if exists)
		git tag ${CSV_VERSION} || true
		git push origin ${CSV_VERSION} || true
	fi
	popd >/dev/null || exit 1
done

# cleanup
# cd /tmp
echo "Temporary checkouts are in /tmp/tmp-checkouts"
# rm -fr /tmp/tmp-checkouts
