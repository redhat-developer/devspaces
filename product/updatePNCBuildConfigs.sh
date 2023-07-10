#!/bin/bash
#
# Copyright (c) 2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to create Product Versions and Build Configs in support of building DevSpaces artifacts

usage() {
  echo "
  Provide a version and type of workflow (next or latest):
  Example: 
    $0 -v 3.6 --latest
    $0 -v 3.7 --next
  "
}

LATEST_UPDATE=
NEXT_UPDATE=
DS_VERSION=

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-v') DS_VERSION="$2"; shift 1;; # set major.minor version (3.yy)
    '--latest') LATEST_UPDATE="true"; shift 0;; # if set true, perform workflow for latest branch
    '--next') NEXT_UPDATE="true"; shift 0;; # if set true, perform workflow for next branch
  esac
  shift 1
done

initVariables() {
  # init variables used by both flows
  product_version=$DS_VERSION
  product_name="RHOSDS"
  project_name="devspaces-server" # maps to project id = 1274
  project_id="1274"
}

configureProductVersion() {
  local product_version="$1"
  product_id=$(pnc product list --query "abbreviation==$product_name" | yq -r '.[].id')
  product_id_version=$(pnc product list-versions "$product_id" | yq -r '.[] | select(.version == "'"$product_version"'") | .id')
  if [[ $product_id_version ]]; then
    echo "[INFO] detected existing PNC version for $product_version: https://orch.psi.redhat.com/pnc-web/#/products/166/versions/${product_id_version}"
  else
    echo "[INFO] creating PNC version for $product_version"
    product_id_version=$(pnc product-version create --product-id="$product_id" "$product_version" | yq -r '.id')
    echo "[INFO] created PNC version for $product_version, id - $product_id_version"
  fi
}

configureLatestBuildConfig() {
  local product_version="$1"
  curl -sSLo /tmp/job-config.json https://raw.githubusercontent.com/redhat-developer/devspaces/devspaces-3-rhel-8/dependencies/job-config.json
  build_config_id=$(pnc build-config list --query "project.name==$project_name;productVersion.version==$product_version;name!=devspaces-server-build-main" | yq -r '.[].id')
  if [[ $build_config_id ]]; then
    echo "[INFO] detected existing PNC build-config for $product_version: https://orch.psi.redhat.com/pnc-web/#/projects/${project_id}/build-configs/${build_config_id}"
  else
    echo "[INFO] cloning PNC build config for $product_version"

    # first, check for reusable orphans with no productVersion or scmRevision
    # pnc build-config list --query "project.name==devspaces-server" | yq -r '.[]|select(.productVersion==null)|.id' ==> 10922
    # pnc build-config list --query "project.name==devspaces-server" | yq -r '.[]|select(.scmRevision=="none")|.id' ==> 10922
    old_build_config_id=$(pnc build-config list --query "project.name==$project_name" | yq -r '.[]|select(.productVersion==null)|.id')
    if [[ ! $old_build_config_id ]]; then
      old_build_config_id=$(pnc build-config list --query "project.name==$project_name" | yq -r '.[]|select(.scmRevision=="none")|.id')
    fi
    # if found, repurpose this old build-config as the new one
    if [[ $old_build_config_id ]]; then
      echo "[INFO] found orphaned PNC build config https://orch.psi.redhat.com/pnc-web/#/projects/1274/build-configs/$old_build_config_id to reuse!" 
      build_config_id="${old_build_config_id}"
    else
      # get previous build config for latest build to base the clone from
      [[ ${product_version} =~ ^([0-9]+)\.([0-9]+)$ ]] && BASE=${BASH_REMATCH[1]}; NEXT=${BASH_REMATCH[2]}; (( NEXT=NEXT-1 )) 
      old_product_version=${BASE}.${NEXT}
      old_build_config_id=$(pnc build-config list --query "project.name==$project_name;productVersion.version==$old_product_version;name!=devspaces-server-build-main" | yq -r '.[].id')
      # fetch job-config.json, where new upstream version is listed
      new_build_config_scmRevision=$(jq -r '.Jobs.server."'"$product_version"'".upstream_branch[0]' /tmp/job-config.json)
      new_build_config_name="devspaces-server-build-$new_build_config_scmRevision"
      build_config_id=$(pnc build-config clone --buildConfigName="$new_build_config_name" --scmRevision="$new_build_config_scmRevision" "$old_build_config_id" | yq -r '.id')
    fi
  fi
  if [[ $build_config_id ]]; then
    # update config to set new name, new product version and scm revision
    new_build_config_scmRevision=$(jq -r '.Jobs.server."'"$product_version"'".upstream_branch[0]' /tmp/job-config.json)
    new_build_config_name="devspaces-server-build-$new_build_config_scmRevision"
    pnc build-config update --product-version-id="$product_id_version" --buildConfigName="$new_build_config_name" --scm-revision="$new_build_config_scmRevision" "$build_config_id"
    echo "[INFO] updated PNC build config for $product_version: https://orch.psi.redhat.com/pnc-web/#/projects/${project_id}/build-configs/${build_config_id}"
  else 
    echo "[ERROR] could not compute build_config_id for product version $product_version !"
    exit 1
  fi
}

configureNextBuildConfig() {
  build_config_name="devspaces-server-build-main"
  build_config_id=$(pnc build-config list --query "project.name==$project_name;name==$build_config_name" | yq -r '.[].id')
  if [[ $build_config_id ]]; then
    echo "[INFO] detected existing PNC build-config for $product_version: https://orch.psi.redhat.com/pnc-web/#/projects/${project_id}/build-configs/${build_config_id}"
    # echo "[INFO] updating PNC build config for $product_version"
    # update config to point to new product version
    pnc build-config update --product-version-id="$product_id_version" "$build_config_id"
    echo "[INFO] updated PNC build config for $product_version: https://orch.psi.redhat.com/pnc-web/#/projects/${project_id}/build-configs/${build_config_id}"
  fi
}

cleanup() {
  rm -f /tmp/job-config.json
}

if [[ -z ${DS_VERSION} ]] || [[ -z ${NEXT_UPDATE} && -z ${LATEST_UPDATE} ]]; then
  usage
  exit 1
fi

initVariables
product_version="${DS_VERSION}"
configureProductVersion "$product_version"
if [[ $LATEST_UPDATE ]]; then
  configureLatestBuildConfig "$product_version"
elif [[ $NEXT_UPDATE ]]; then
  configureNextBuildConfig
  # now update the :latest entry using the 3.y-1 version
  [[ ${DS_VERSION} =~ ^([0-9]+)\.([0-9]+)$ ]] && BASE=${BASH_REMATCH[1]}; NEXT=${BASH_REMATCH[2]}; (( NEXT=NEXT-1 )) 
  product_version="${BASE}.${NEXT}"
  configureProductVersion "$product_version"
  configureLatestBuildConfig "$product_version"
fi
cleanup

