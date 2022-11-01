#!/bin/bash
#
# Copyright (c) 2018-2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Add additional images that are not referenced in meta.yaml files but which are used 
# in deployment. These images can then be used when configuring imagepuller
#
# see https://issues.redhat.com/browse/CRW-3429

CONTAINERS=(
    # TODO: pin to specific version of DWO from https://github.com/redhat-developer/devspaces/blob/devspaces-3-rhel-8/dependencies/job-config.json#L1026 ?
    "registry.redhat.io/devworkspace/devworkspace-project-clone-rhel8"
    # TODO: pin to specific version of DS from https://github.com/redhat-developer/devspaces/blob/devspaces-3-rhel-8/dependencies/job-config.json#L3 ?
    "registry.redhat.io/devspaces/traefik-rhel8"
)
for c in "${CONTAINERS[@]}"; do
  echo "$c"
done
