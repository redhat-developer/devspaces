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
To create tags (and push updated CSV content into operator-bundle repo):
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
    '-t') CRW_VERSION="$2"; shift 1;; # 2.y # used to get released bundle container's CSV contents
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

pushTagPD () 
{
	d="$1"
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
}

# tag pkgs.devel repos only (branches are created by SPMM ticket, eg., https://projects.engineering.redhat.com/browse/SPMM-2517)
# TODO remove tagging for backup and operator-metadata once 2.15 is live
if [[ ${pkgs_devel_branch} ]] && [[ ${CSV_VERSION} ]]; then 
	for d in \
	codeready-workspaces-configbump \
	codeready-workspaces-operator \
	codeready-workspaces-operator-bundle \
	codeready-workspaces-dashboard \
	\
	codeready-workspaces-devfileregistry \
	codeready-workspaces-idea \
	codeready-workspaces-imagepuller \
	codeready-workspaces-jwtproxy \
	codeready-workspaces-machineexec \
	\
	codeready-workspaces-pluginbroker-artifacts \
	codeready-workspaces-pluginbroker-metadata \
	codeready-workspaces-pluginregistry \
	codeready-workspaces \
	codeready-workspaces-theia-dev \
	\
	codeready-workspaces-theia-endpoint \
	codeready-workspaces-theia \
	codeready-workspaces-traefik \
	codeready-workspaces-udi \
	; do
	  pushTagPD $d
	done
fi

# for the crw main repo, update tech preview devfiles to point to the correct tag/branch
updateTechPreviewDevfiles() {
    YAML_ROOT="tech-preview-devfiles"

    # replace CRW devfiles with image references to current version tag instead of crw-2-rhel-8 and :latest tag
    for devfile in $(find ${YAML_ROOT} -name "*.yaml" -o -name "*.yml"); do
       sed -r -i "${devfile}" \
           -e "s|(.*image: \"*?.*quay.io/crw/.*:).+|\1${CRW_VERSION}\"|g" \
           -e "s|(.*image: \"*?.*registry.redhat.io/codeready-workspaces/.*:).+|\1${CRW_VERSION}\"|g" \
           -e "s|codeready-workspaces/crw-2-rhel-8/|codeready-workspaces/crw-${CRW_VERSION}-rhel-8/|g"
    done
    git diff -q "${YAML_ROOT}" || true
    git commit -a -s -m "chore(tech-preview-devfiles) update tag/branch to ${CRW_VERSION}"
}

# for the crw main repo, update meta.yaml files to point to the correct branch of crw-sample 
updatelinksToDevfiles() {
    YAML_ROOT="dependencies/che-devfile-registry/devfiles"

    # replace CRW devfiles with image references to current version tag instead of crw-2-rhel-8 and :latest tag
    for meta in $(find ${YAML_ROOT} -name "meta.yaml"); do
       sed -r -i "${meta}" \
           -e "s|devfilev2|${CRW_VERSION}-devfilev2/|g"
    done
    git diff -q "${YAML_ROOT}" || true
    git commit -a -s -m "chore(devfile) update link to devfiles v2"
}

pushTagGH () {
	d="$1"
	org="$2"
	echo; echo "== $d =="
	if [[ ${SOURCE_BRANCH} ]]; then clone_branch=${SOURCE_BRANCH}; else clone_branch=${crw_repos_branch}; fi
	if [[ ! -d /tmp/tmp-checkouts/projects_${d} ]]; then
		git clone --depth 1 -b ${clone_branch} https://github.com/${org}/${d}.git projects_${d}
		pushd /tmp/tmp-checkouts/projects_${d} >/dev/null || exit 1
			export GITHUB_TOKEN="${GITHUB_TOKEN}"
			git config user.email "nickboldt+devstudio-release@gmail.com"
			git config user.name "Red Hat Devstudio Release Bot"
			git config --global push.default matching
			git config --global hub.protocol https
			git remote set-url origin https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${org}/${d}.git

			git checkout --track origin/${clone_branch} -q || true
			git pull -q
		popd >/dev/null || exit 1
	fi
	pushd /tmp/tmp-checkouts/projects_${d} >/dev/null || exit 1
	if [[ ${SOURCE_BRANCH} ]]; then # push a new branch (or no-op if exists)
		branch=${crw_repos_branch}
		if [[ $org == "crw-samples" ]]; then 
			# new branch for crw-sample should be 2.x-devfilev2
			branch=$(echo "$crw_repos_branch" | cut -f2 -d'-')"-$SOURCE_BRANCH";
		fi
		
		git branch ${branch} || true

		# for the crw main repo, update tech preview devfiles to point to the correct tag/branch
		if [[ $d == "codeready-workspaces" ]]; then 
			updateTechPreviewDevfiles;
			updatelinksToDevfiles;
		fi

		git push origin ${branch} || true
	fi
	if [[ $CSV_VERSION ]]; then # push a new tag (or no-op if exists)
		git tag ${CSV_VERSION} || true
		git push origin ${CSV_VERSION} || true
	fi
	popd >/dev/null || exit 1
}

org="redhat-developer"
for d in \
codeready-workspaces \
codeready-workspaces-chectl \
codeready-workspaces-images \
codeready-workspaces-theia \
; do
	pushTagGH $d $org
done

# create branches for crw samples
# all samples are located in https://github.com/orgs/crw-samples
# the source branch is devfilev2
org="crw-samples"
SOURCE_BRANCH="devfilev2"
for s in \
jboss-eap-quickstarts \
microprofile-quickstart-bootable \
microprofile-quickstart \
fuse-rest-http-booster \
camel-k \
rest-http-example \
gs-validating-form-input \
lombok-project-sample \
quarkus-quickstarts \
vertx-health-checks-example-redhat \
vertx-http-example \
nodejs-configmap \
nodejs-mongodb-sample \
web-nodejs-sample \
python-hello-world \
c-plus-plus \
dotnet-web-simple \
golang-health-check \
cakephp-ex \
demo \
gradle-demo-project \
; do
	pushTagGH $s $org
done

# cleanup
# cd /tmp
echo "Temporary checkouts are in /tmp/tmp-checkouts"
rm -fr /tmp/tmp-checkouts
