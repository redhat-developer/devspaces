# Copyright (c) 2019 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

# For the latest released Dockerfile see:
# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/codeready-workspaces/server
FROM registry.access.redhat.com/codeready-workspaces/server

# Or build the latest nightly from pulp (RH internal) or quay (public)
# FROM brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888/codeready-workspaces/server-container
# FROM quay.io/crw/server-container