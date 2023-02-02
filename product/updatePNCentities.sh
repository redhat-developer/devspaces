#!/bin/bash
#
# Copyright (c) 2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to manage Project Newcastle entities and configuration for building DevSpaces artifacts

usage() {
          echo "
          Provide a version and type of workflow (next or latest):
          Example: 
                    $0 -v 3.4 --latest
                    $0 -v 3.5 --next
          "
}

if [[ $# -lt 3 ]]; then
	usage
	exit 1
fi

STABLE_UPDATE=
NEXT_UPDATE=
DS_VERSION=

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
	'-v') DS_VERSION="$2"; shift 1;; # set major version
	'--latest') STABLE_UPDATE="true"; shift 0;; # if set true, perform workflow for latest branch
          '--next') NEXT_UPDATE="true"; shift 0;; # if set true, perform workflow for next branch
  esac
  shift 1
done

initVariables() {
          # init variables used by both flows
          pnc_ds_server_product_version=$DS_VERSION
          pnc_ds_server_product_name="devspaces-server"
          pnc_ds_server_project_name="devspaces-server"
}

configureProductVersion() {
          pnc_ds_server_product_id=$(pnc product list  --query "name==$pnc_ds_server_product_name" | yq -r '.[].id')
          pnc_ds_server_product_version_id=$(pnc product list-versions $pnc_ds_server_product_id | yq -r '.[] | select(.version == "'$DS_VERSION'") | .id')
          if [[ $pnc_ds_server_product_version_id ]]; then 
                    echo "[INFO] detected existing PNC version for $DS_VERSION, id - $pnc_ds_server_product_version_id"
          else
                    echo "[INFO] creating PNC version for $DS_VERSION"
                    pnc_ds_server_product_version_id=$(product-version create --product-id=$pnc_ds_server_product_id $pnc_ds_server_product_version | yq -r '.id')
                    echo "[INFO] creadted PNC version for $DS_VERSION, id - $pnc_ds_server_product_version_id"
          fi
}

configureStableBuildConfig() {
          pnc_ds_server_project_build_config_id=$(pnc build-config list --query "project.name==$pnc_ds_server_project_name;productVersion.version==$pnc_ds_server_product_version" | yq -r '.[].id')
          if [[ $pnc_ds_server_project_build_config_id ]]; then 
                    echo "[INFO] detected existing PNC build-config for $pnc_ds_server_product_version, id - $pnc_ds_server_project_build_config_id"
          else
                    echo "[INFO] cloning PNC build config for $pnc_ds_server_product_version"
                    # get previous build config for latest build to base the clone from
                    [[ ${DS_VERSION} =~ ^([0-9]+)\.([0-9]+)$ ]] && BASE=${BASH_REMATCH[1]}; NEXT=${BASH_REMATCH[2]}; (( NEXT=NEXT-1 )) 
                    old_ds_product_version=${BASE}.${NEXT}
                    old_ds_buildConfigId=$(pnc build-config list --query "project.name==$pnc_ds_server_project_name;productVersion.version==$old_ds_product_version")
                    # fetch job-config.json, where new upstream version is listed
                    curl -sSLo /tmp/job-config.json https://raw.githubusercontent.com/redhat-developer/devspaces/devspaces-3-rhel-8/dependencies/job-config.json 
                    new_ds_scmRevision=$(jq -r '.Jobs.server."'$pnc_ds_server_product_version'".upstream_branch[0]' /tmp/job-config.json)
                    new_ds_buildConfigName="devspaces-server-build-$new_ds_scmRevision"
                    pnc_ds_server_project_build_config_id=$(pnc build-config clone \
                                                            --buildConfigName=$new_ds_buildConfigName \
                                                            --scmRevision=$new_ds_scmRevision \
                                                            $old_ds_buildConfigId)	
                    # update config to point to new product version
                    pnc build-config update --product-version-id=$pnc_ds_server_product_version_id $pnc_ds_server_project_build_config_id
                    echo "[INFO] created PNC build config for $pnc_ds_server_product_version, id - $pnc_ds_server_project_build_config_id"
          fi
}

configureNextBuildConfig() {
          pnc_ds_server_build_config_name="devspaces-server-build-main"

          pnc_ds_server_project_build_config_id=$(pnc build-config list --query "project.name==$pnc_ds_server_project_name;name==$pnc_ds_server_build_config_name" | yq -r '.[].id')
          if [[ $pnc_ds_server_project_build_config_id ]]; then 
                    echo "[INFO] detected existing PNC build-config for $pnc_ds_server_product_version, id - $pnc_ds_server_project_build_config_id"
                    echo "[INFO] updating PNC build config for $pnc_ds_server_product_version"
                    # update config to point to new product version
                    pnc build-config update --product-version-id=$pnc_ds_server_product_version_id $pnc_ds_server_project_build_config_id
                    echo "[INFO] updated PNC build config for $pnc_ds_server_product_version, id - $pnc_ds_server_project_build_config_id"
          fi
}

if [[ -z $DS_VERSION || -z $NEXT_UPDATE && -z $STABLE_UPDATE ]]; then
          usage
fi

initVariables
configureProductVersion
if [[ $STABLE_UPDATE ]]; then
          configureStableBuildConfig
elif [[ $NEXT_UPDATE ]]; then
          configureNextBuildConfig
fi