#!/bin/bash
#
# Copyright (c) 2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to manage Project Newcastle entities during release

showHelp() {
          echo "
          Provide a version and type of workflow (next or stable):
          Example: 
                    $0 -v 3.4 --stable
                    $0 -v 3.5 --next
          "
}

if [[ $# -lt 3 ]]; then
	showHelp
	exit 1
fi

STABLE_UPDATE=
NEXT_UPDATE=
DS_VERSION=

# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
	'-v') DS_VERSION="$2"; shift 1;; # set major version
	'--stable') STABLE_UPDATE="true"; shift 0;; # if set true, perform workflow for stable branch
          '--next') NEXT_UPDATE="true"; shift 0;; # if set true, perform workflow for next branch
  esac
  shift 1
done

initVariables() {
          # init variables used by both flows
          pnc_ds_server_product_version=$DS_VERSION
          pnc_ds_server_product_milestone_version=$DS_VERSION.0
          pnc_ds_server_product_release_version=$DS_VERSION.0.GA
          pnc_ds_server_product_name="devspaces-server"

          pnc_ds_server_project_name="devspaces-server"
}

updateStablePNCentities() {
          # build-config prod = 
          # Project Newcastle updates for devspaces-server:

          pnc_ds_server_product_name="devspaces-server"
          pnc_ds_server_product_id=$(pnc product list  --query "name==$pnc_ds_server_product_name" | yq -r '.[].id')

          # 1.Product entities - version, milestone and release
          # version:
          pnc_ds_server_product_version_id=$(pnc product list-versions $pnc_ds_server_product_id | yq -r '.[] | select(.version == "'$DS_VERSION'") | .id')
          if [[ $pnc_ds_server_product_version_id ]]; then 
                    echo "[INFO] detected existing PNC version for $DS_VERSION, id - $pnc_ds_server_product_version_id"
          else
                    echo "[INFO] creating PNC version for $DS_VERSION"
                    pnc_ds_server_product_version_id=$(product-version create --product-id=$pnc_ds_server_product_id $pnc_ds_server_product_version | yq -r '.id')
                    echo "[INFO] creadted PNC version for $DS_VERSION, id - $pnc_ds_server_product_version_id"
          fi
          # milestone
          pnc_ds_server_product_milestone_id=$(pnc product list-versions $pnc_ds_server_product_version_id | \
                                                  yq -r '.[].productMilestones | \
                                                  select(.[].version == "'$pnc_ds_server_product_milestone_version'") | \
                                                  .id')
          if [[ $pnc_ds_server_product_milestone_id ]]; then 
                    echo "[INFO] detected existing PNC milestone for $pnc_ds_server_product_milestone_version, id - $pnc_ds_server_product_milestone_id"
          else
                    echo "[INFO] creating PNC milestone for $pnc_ds_server_product_milestone_version"
                    # TODO replace dummy values of required dates?
                    pnc_ds_server_product_milesttone_starting_date=2030-01-01
                    pnc_ds_server_product_milesttone_end_date=2030-01-01
                    pnc_ds_server_product_milestone_id=$(pnc product-milestone create \
                                                            --product-id=$pnc_ds_server_product_id \
                                                            --starting-date=$pnc_ds_server_product_milesttone_starting_date \
                                                            --end-date=$pnc_ds_server_product_milesttone_end_date \
                                                            $pnc_ds_server_product_milestone_version)
                    echo "[INFO] creadted PNC milestone for $pnc_ds_server_product_milestone_version, id - $pnc_ds_server_product_milestone_id"
          fi
          # release
          pnc_ds_server_product_release_id=$(pnc product list-versions $pnc_ds_server_product_version_id | \
                                                  yq -r '.[].productReleases | \
                                                  select(.[].version == "'$pnc_ds_server_product_release_version'") | \
                                                  .id')
          if [[ $pnc_ds_server_product_release_id ]]; then 
                    echo "[INFO] detected existing PNC release for $pnc_ds_server_product_release_version, id - $pnc_ds_server_product_release_id"
          else
                    echo "[INFO] creating PNC release for $pnc_ds_server_product_release_version"
                    # TODO replace dummy values of required dates?
                    pnc_ds_server_product_release_date=2030-01-01
                    pnc_ds_server_product_release_id=$(pnc product-release create \
                                                            --milestone-id=$pnc_ds_server_product_milestone_id \
                                                            --release-date=$pnc_ds_server_product_release_date \
                                                            --support-level SUPPORTED \
                                                            $pnc_ds_server_product_release_version)
                    echo "[INFO] creadted PNC release for $pnc_ds_server_product_release_version, id - $pnc_ds_server_product_release_id"
          fi
          # 2. Project entity - build-config
          #TODO How to evaluate Che version. From product-json?
          pnc_ds_server_project_name="devspaces-server"
          pnc_ds_server_project_id=$(pnc project list  --query "name==mkuznets-test" | yq -r '.[].id')

          pnc_ds_server_project_build_config_id=$(pnc build-config list --query "project.name==$pnc_ds_server_project_name;productVersion.version==$pnc_ds_server_product_version" | yq -r '.[].id')
          if [[ $pnc_ds_server_project_build_config_id ]]; then 
                    echo "[INFO] detected existing PNC build-config for $DS_VERSION, id - $pnc_ds_server_project_build_config_id"
          else
                    echo "[INFO] creating PNC build config for $DS_VERSION"
                    # TODO better algoritm?
                    # calculate previos version of devspaces
                    [[ ${DS_VERSION} =~ ^([0-9]+)\.([0-9]+)$ ]] && BASE=${BASH_REMATCH[1]}; NEXT=${BASH_REMATCH[2]}; (( NEXT=NEXT-1 )) 
                    previous_product_version=${BASE}.${NEXT}
                    # search for config for previous version and get its name and version
                    # name: devspaces-server-build-7.52
                    # rev: 7.52.x
                    previous_ds_base_config=$(pnc build-config list --query "project.name==$pnc_ds_server_project_name;productVersion.version==$previous_product_version")
                    previous_ds_base_buildConfigName=echo $previous_ds_base_config | yq -r '.[].id'
                    previous_ds_base_scmRevision=
                    # bump upstream Che revision reference by .2
                    new_ds_buildConfigName=
                    new_ds_scmRevision=

                    pnc_ds_server_project_build_config_id=$(pnc build-config clone \
                                                            --buildConfigName=devspaces-server-build-7.52 \
                                                            --scmRevision=$new_ds_scmRevision \
                                                            $previous_ds_base_config_id)	
                    # update config to point to new product version
                    pnc build-config update --product-version-id=$pnc_ds_server_product_version_id $pnc_ds_server_project_build_config_id
                    echo "[INFO] created PNC build config for $pnc_ds_server_product_version, id - $pnc_ds_server_project_build_config_id"
          fi
}


updateNextPNCentities() {
          # get build config for main branch and set its product version
          pnc_ds_server_project_name="devspaces-server"
          pnc_ds_server_build_config_name="devspaces-server-build-main"
          
          pnc_ds_server_project_build_config_id=$(pnc build-config list --query "project.name==$pnc_ds_server_project_name;productVersion.version==$pnc_ds_server_product_version" | yq -r '.[].id')

          
          pnc build-config update --product-version-id=$pnc_ds_server_product_version_id $pnc_ds_server_project_build_config_id
}

if [[ -z $DS_VERSION || -z $NEXT_UPDATE && -z $STABLE_UPDATE ]]; then
          showHelp
fi

initVariables
if [[ $STABLE_UPDATE ]]; then
          updateStablePNCentities
elif [[ $NEXT_UPDATE ]]; then
          updateNextPNCentities
fi