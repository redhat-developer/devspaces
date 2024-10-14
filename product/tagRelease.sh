#!/bin/bash
#
# Copyright (c) 2018-2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to tag the Che/devspaces repos for a given release
# as well as create/update branches and related PNC build-configs

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")
# defaults
# try to compute branches from currently checked out branch; else fall back to hard coded value
TARGET_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ $TARGET_BRANCH != "devspaces-3."*"-rhel-8" ]]; then
	TARGET_BRANCH="devspaces-3-rhel-8"
fi
pkgs_devel_branch=${TARGET_BRANCH}

pduser=devspaces-build

samplesRepo=devspaces-samples

SOURCE_BRANCH="" # normally, use this script to create tags, not branches

CLEAN="false" #  if set true, delete existing folders and do fresh checkouts

if [[ $# -lt 4 ]]; then
	echo "
To create tags (and push updated CSV content into operator-bundle repo):
  $0 -v CSV_VERSION -t DS_VERSION -gh DS_GH_BRANCH -ghtoken GITHUB_TOKEN -pd PKGS_DEVEL_BRANCH -pduser kerberos_user
Example: 
  $0 -v 3.y.0 -t 3.y -gh ${TARGET_BRANCH} -ghtoken \$GITHUB_TOKEN -pd ${pkgs_devel_branch} -pduser $pduser

To create or update existing branches and update related PNC build-configs:
  $0 -t DS_VERSION --branchfrom SOURCE_GH_BRANCH -gh TARGET_GH_BRANCH -ghtoken GITHUB_TOKEN
Example: 
  $0 -t DS_VERSION --branchfrom devspaces-3-rhel-8 -gh ${TARGET_BRANCH} -ghtoken \$GITHUB_TOKEN
"
	exit 1
fi

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
	'--branchfrom') SOURCE_BRANCH="$2"; shift 1;; # this flag will create branches instead of using branches to create tags
	'-v') CSV_VERSION="$2"; shift 1;; # 3.y.0
	'-t') DS_VERSION="$2"; shift 1;; # 3.y # used to get released bundle container's CSV contents
	'-gh') TARGET_BRANCH="$2"; shift 1;;
	'-ghtoken') GITHUB_TOKEN="$2"; shift 1;;
	'-pd') pkgs_devel_branch="$2"; shift 1;;
	'-pduser') pduser="$2"; shift 1;;
	'--clean') CLEAN="true"; shift 0;; # if set true, delete existing folders and do fresh checkouts
  esac
  shift 1
done

if [[ ! ${DS_VERSION} ]]; then
  DS_VERSION=${CSV_VERSION%.*} # given 3.y.0, want 3.y
fi

if [[ ${CLEAN} == "true" ]]; then
	rm -fr /tmp/tmp-checkouts || true
fi

mkdir -p /tmp/tmp-checkouts
cd /tmp/tmp-checkouts

set -e

pushTagPD () 
{
	d="$1"
	echo; echo "== $d =="
	if [[ ! -d "/tmp/tmp-checkouts/containers_${d}" ]]; then
		git clone -b "${pkgs_devel_branch}" "ssh://${pduser}@pkgs.devel.redhat.com/containers/${d}" "containers_${d}"
		pushd "/tmp/tmp-checkouts/containers_${d}" >/dev/null || exit 1
			export KRB5CCNAME=/var/tmp/${pduser}_ccache
			git config user.email "${pduser}@REDHAT.COM"
			git config user.name "Dev Spaces Build"
			git config --global push.default matching

			git checkout --track origin/"${pkgs_devel_branch}" -q || true
			git pull -q
		popd >/dev/null || exit 1
	fi
	pushd "/tmp/tmp-checkouts/containers_${d}" >/dev/null || exit 1
		# push new tag (no op if already exists)
		git tag -a "${CSV_VERSION}" -m "${CSV_VERSION}" || true
		git push origin "${CSV_VERSION}" || true
	popd >/dev/null || exit 1
}

toggleQuayRHECReferences() {
	YAML_ROOT="dependencies/"
	# replace DS meta.yaml files with links to current version of devfile v2
	# shellcheck disable=SC2044
	for yaml in $(find ${YAML_ROOT} -name "*.yaml"); do
		sed -r -i "$yaml" -e "s#quay.io/devspaces/#registry.redhat.io/devspaces/#g"
	done
	git commit -s -m "chore(yaml) set image refs to registry.redhat.io/devspaces/" $YAML_ROOT || echo ""
}

# for the devspaces main repo, update meta.yaml files to point to the correct branch of $samplesRepo
updateImageTags() {
	YAML_ROOT="dependencies/che-plugin-registry/"
	# shellcheck disable=SC2044
	for cheyaml in $(find ${YAML_ROOT} -name "che-*.yaml"); do
	   sed -r -i "${cheyaml}" \
		   -e "s|(image: .+/devspaces/.+):[0-9.]+|\1:${DS_VERSION}|g"
	done
	git commit -s -m "chore(che-*.yaml) update devspaces image tags to :${DS_VERSION}" $YAML_ROOT || echo ""
}

# for the sample projects ONLY, commit changes to the devfile so it contains the correct image and tag
updateSampleDevfileReferences () {
	devfile=devfile.yaml
	if [[ $DS_VERSION ]]; then
		DS_TAG="$DS_VERSION"
	else
		DS_TAG="${TARGET_BRANCH//-rhel-8}"; DS_TAG="${DS_TAG//devspaces-}"
	fi
	# echo "[DEBUG] update $devfile with DS_TAG = $DS_TAG"
	sed -r -i $devfile \
		-e "s#devspaces/(.+)[:@][0-9:@.-]+#devspaces/\1:${DS_TAG}#g"

	sed -r -i $devfile -e "s#quay.io/devspaces/#registry.redhat.io/devspaces/#g"
	git commit -s -m "chore(devfile) link v2 devfile to :${DS_TAG}; set image refs to registry.redhat.io/devspaces/" "$devfile" || echo ""
}

# create branch or tag
pushBranchAndOrTagGH () {
	d="$1"
	org="$2"
	echo; echo "== $d =="
	# if source_branch defined and target branch doesn't exist yet, check out the source branch
	if [[ ${SOURCE_BRANCH} ]] && [[ $(git ls-remote --heads "https://github.com/${org}/${d}" "${TARGET_BRANCH}") == "" ]]; then
		clone_branch=${SOURCE_BRANCH}
	else # if source branch not set (tagging operation) or target branch already exists
		clone_branch=${TARGET_BRANCH}
	fi
	if [[ ! -d "/tmp/tmp-checkouts/projects_${d}" ]]; then
		git clone -q --depth 1 -b "${clone_branch}" "https://github.com/${org}/${d}" "projects_${d}"
		pushd "/tmp/tmp-checkouts/projects_${d}" >/dev/null || exit 1
			export GITHUB_TOKEN="${GITHUB_TOKEN}"
			git config user.email "nickboldt+devstudio-release@gmail.com"
			git config user.name "Red Hat Devstudio Release Bot"
			git config --global push.default matching
			git config --global hub.protocol https
			git remote set-url origin "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${org}/${d}"

			git checkout --track "origin/${clone_branch}" -q || true
			git pull -q
		popd >/dev/null || exit 1
	fi
	pushd "/tmp/tmp-checkouts/projects_${d}" >/dev/null || exit 1
	if [[ ${SOURCE_BRANCH} ]]; then 
		# create a branch or use existing
		git branch "${TARGET_BRANCH}" || true
		git checkout "${TARGET_BRANCH}" || true
		git pull origin "${TARGET_BRANCH}" || true

		# for the devspaces main repo, update devfiles to point to the correct tag/branch
		if [[ $d == "devspaces" ]]; then
			toggleQuayRHECReferences
			updateImageTags
		fi

		# for the devspaces sample repos, update devfiles to point to the correct tag/branch
		if [[ $org == "${samplesRepo}" ]]; then
			updateSampleDevfileReferences
		fi

		git pull origin "${TARGET_BRANCH}" || true
		git push origin "${TARGET_BRANCH}" || true
	fi
	if [[ $CSV_VERSION ]]; then # push a new tag (or no-op if exists)
		git tag "${CSV_VERSION}" || true
		git push origin "${CSV_VERSION}" || true
		# update latest floating tag for samples
		if [[ $org == "${samplesRepo}" ]]; then
			# check all of the 3.*.* tags in the repo, if tag exists with a higher version than the new tag
			# then latest floating tag should not be updated
			LATEST_TAG=$(git tag -l -n 3.*.* --sort -version:refname | head -n 1 | grep -o "^3\.[0-9]*\.[0-9]*")
			if { echo "${CSV_VERSION}"; echo "${LATEST_TAG}"; } | sort -V --check=silent && [[ "${CSV_VERSION}" != "${LATEST_TAG}" ]];then
				echo "[DEBUG] Sample version ${d} is less than latest ${LATEST_TAG} version, not updating the latest tag";
			else
				echo "[DEBUG] Updating latest tag of sample ${d} with ${CSV_VERSION}"
				git tag -d "latest" || true
				git tag "latest"
				git push origin "latest" -f
			fi
		fi
	fi
	popd >/dev/null || exit 1
}

updatePNCBuildConfigs() {
  if [[ ! -x ${SCRIPTPATH}/updatePNCBuildConfigs.sh ]]; then
    curl -sSLo /tmp/updatePNCBuildConfigs.sh https://raw.githubusercontent.com/redhat-developer/devspaces/${MIDSTM_BRANCH}/product/updatePNCBuildConfigs.sh
    chmod +x /tmp/updatePNCBuildConfigs.sh
    PNC_SCRIPT_LOCATION="/tmp/updatePNCBuildConfigs.sh"
  else
    PNC_SCRIPT_LOCATION="${SCRIPTPATH}/updatePNCBuildConfigs.sh"
  fi
  # if source and target branch are the same, we're updating the 3.x / next branch; else we're updating the 3.yy / latest branch
  if [ "${TARGET_BRANCH}" == "${SOURCE_BRANCH}" ];then
    ${PNC_SCRIPT_LOCATION} -v ${DS_VERSION} --next
  else
    ${PNC_SCRIPT_LOCATION} -v ${DS_VERSION} --latest
  fi
}

# tag pkgs.devel repos only (branches are created by SPMM ticket, eg., https://projects.engineering.redhat.com/browse/SPMM-2517)
if [[ "${pkgs_devel_branch}" ]] && [[ "${CSV_VERSION}" ]]; then
	for repo in \
	devspaces-code \
	devspaces-configbump \
	devspaces-dashboard \
	devspaces-jetbrains-ide \
	devspaces-idea \
	devspaces-imagepuller \
	\
	devspaces-machineexec \
	devspaces-operator \
	devspaces-operator-bundle \
	devspaces-pluginregistry \
	devspaces-server \
	\
	devspaces-traefik \
	devspaces-udi \
	; do
	  pushTagPD $repo
	done
	# cleanup
	rm -fr /tmp/tmp-checkouts/*
fi

for repo in \
devspaces \
devspaces-chectl \
devspaces-images \
devspaces-vscode-extensions \
; do
	pushBranchAndOrTagGH $repo "redhat-developer"
done
# cleanup
rm -fr /tmp/tmp-checkouts/*

####### sample projects: branching and tagging
# cat devspaces-devfileregistry/devfiles/*/meta.* | grep v2 | sort
sampleprojects="\
c-plus-plus \
dotnet-web-simple \
golang-health-check \
lombok-project-sample \
nodejs-mongodb-sample \
php-hello-world \
python-hello-world \
quarkus-quickstarts \
web-nodejs-sample \
ansible-devspaces-demo \
"

# create branches for devspaces samples, located under https://github.com/${samplesRepo}/
for s in $sampleprojects; do
	pushBranchAndOrTagGH "$s" ${samplesRepo}
done

# update PNC build-configs, only if performing branching operation (not when tagging)
if [[ ${SOURCE_BRANCH} ]]; then
  updatePNCBuildConfigs
fi

# cleanup
rm -fr /tmp/tmp-checkouts /tmp/updatePNCBuildConfigs.sh
