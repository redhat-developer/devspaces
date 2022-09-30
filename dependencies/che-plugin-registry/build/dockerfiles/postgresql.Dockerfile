# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

FROM registry.access.redhat.com/ubi8/ubi:8.6-943 as builder

RUN yum install -y wget

RUN wget https://download.postgresql.org/pub/repos/yum/13/redhat/rhel-8-x86_64/postgresql13-13.8-1PGDG.rhel8.x86_64.rpm -P /tmp && \
    wget https://download.postgresql.org/pub/repos/yum/13/redhat/rhel-8-x86_64/postgresql13-libs-13.8-1PGDG.rhel8.x86_64.rpm -P /tmp && \
    wget https://download.postgresql.org/pub/repos/yum/13/redhat/rhel-8-x86_64/postgresql13-server-13.8-1PGDG.rhel8.x86_64.rpm -P /tmp

RUN tar -czvf postgresql13.tar.gz tmp
