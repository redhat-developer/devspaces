# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

FROM registry.access.redhat.com/ubi8/ubi:8.6-943 as builder

RUN yum install -y -q curl && \
    cd /tmp; for arch in x86_64 ppc64le; do \
        for rpm in postgresql13 postgresql13-libs postgresql13-server; do \
            curl -SLO https://download.postgresql.org/pub/repos/yum/13/redhat/rhel-8-${arch}/${rpm}-13.8-1PGDG.rhel8.${arch}.rpm; \
        done && \
        tar -czvf postgresql13-${arch}.tar.gz /tmp/*${arch}.rpm; \
    done && cd /tmp; for arch in s390x; do \
        for rpm in postgresql13 postgresql13-libs postgresql13-server; do \
            curl -SLO https://rpmfind.net/linux/opensuse/ports/zsystems/tumbleweed/repo/oss/${arch}/${rpm}-13.8-1.1.${arch}.rpm; \
        done && \
        tar -czvf postgresql13-${arch}.tar.gz /tmp/*${arch}.rpm; \
    done
