#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#   IBM Corporation - implementation
#

# Simple container for checking the contents of a content-set for rpms

# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/ubi8-minimal
FROM registry.redhat.io/ubi8-minimal:8.5-204
USER 0
COPY content_set*.repo /etc/yum.repos.d/

# show what's installed
# RUN rpm -qa | sort -V 

# query for other stuff with 
# RUN microdnf repoquery ${regex}

# install dnf for better rpm querying
RUN microdnf -y install dnf
# RUN dnf search ${regex}
