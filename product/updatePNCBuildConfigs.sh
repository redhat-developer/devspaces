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
  project_name="devspaces-server"
}

configureProductVersion() {
  product_id=$(pnc product list  --query "abbreviation==$product_name" | yq -r '.[].id')
  product_id_version=$(pnc product list-versions "$product_id" | yq -r '.[] | select(.version == "'"$DS_VERSION"'") | .id')
  if [[ $product_id_version ]]; then 
    echo "[INFO] detected existing PNC version for $DS_VERSION, id - $product_id_version"
  else
    echo "[INFO] creating PNC version for $DS_VERSION"
    product_id_version=$(pnc product-version create --product-id="$product_id" "$product_version" | yq -r '.id')
    echo "[INFO] creadted PNC version for $DS_VERSION, id - $product_id_version"
  fi
}

configureLatestBuildConfig() {
  build_config_id=$(pnc build-config list --query "project.name==$project_name;productVersion.version==$product_version" | yq -r '.[].id')
  if [[ $build_config_id ]]; then 
    echo "[INFO] detected existing PNC build-config for $product_version, id - $build_config_id"
  else
    echo "[INFO] cloning PNC build config for $product_version"
    # get previous build config for latest build to base the clone from
    [[ ${DS_VERSION} =~ ^([0-9]+)\.([0-9]+)$ ]] && BASE=${BASH_REMATCH[1]}; NEXT=${BASH_REMATCH[2]}; (( NEXT=NEXT-1 )) 
    old_product_version=${BASE}.${NEXT}
    old_build_config_id=$(pnc build-config list --query "project.name==$project_name;productVersion.version==$old_product_version" | yq -r '.[].id')
    # fetch job-config.json, where new upstream version is listed
    curl -sSLo /tmp/job-config.json https://raw.githubusercontent.com/redhat-developer/devspaces/devspaces-3-rhel-8/dependencies/job-config.json 
    new_build_config_scmRevision=$(jq -r '.Jobs.server."'"$product_version"'".upstream_branch[0]' /tmp/job-config.json)
    new_build_config_name="devspaces-server-build-$new_build_config_scmRevision"
    build_config_id=$(pnc build-config clone --buildConfigName="$new_build_config_name" --scmRevision="$new_build_config_scmRevision" "$old_build_config_id" | yq -r '.id')
    # update config to point to new product version
    pnc build-config update --product-version-id="$product_id_version" "$build_config_id"
    echo "[INFO] created PNC build config for $product_version, id - $build_config_id"
  fi
}

configureNextBuildConfig() {
  build_config_name="devspaces-server-build-main"
  build_config_id=$(pnc build-config list --query "project.name==$project_name;name==$build_config_name" | yq -r '.[].id')
  if [[ $build_config_id ]]; then 
    echo "[INFO] detected existing PNC build-config for $product_version, id - $build_config_id"
    echo "[INFO] updating PNC build config for $product_version"
    # update config to point to new product version
    pnc build-config update --product-version-id="$product_id_version" "$build_config_id"
    echo "[INFO] updated PNC build config for $product_version, id - $build_config_id"
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
configureProductVersion
if [[ $LATEST_UPDATE ]]; then
  configureLatestBuildConfig
elif [[ $NEXT_UPDATE ]]; then
  configureNextBuildConfig
fi
cleanup

