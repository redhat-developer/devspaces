# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

FROM registry.access.redhat.com/ubi8/python-38:1-107 as builder
USER 0

ENV PATH="/tmp/opt/nodejs/bin:$PATH" \
    npm_config_cache=/tmp/opt/cache

RUN yum install curl -y -q --nodocs

USER 1001

RUN mkdir -p /tmp/opt/nodejs && mkdir -p /tmp/otp/cache &&\
    UNAME=$(uname -m); if [[ $UNAME == "x86_64" ]]; then UNAME="x64"; fi && \
    curl -sSL "https://nodejs.org/download/release/v16.17.1/node-v16.17.1-linux-${UNAME}.tar.gz" | tar xzf - -C /tmp/opt/nodejs --strip-components=1

# install the ovsx cli
RUN npm install -g ovsx@0.5.0 && chmod -R g+rwX /tmp/opt/nodejs
RUN cp -r /tmp/opt/nodejs/lib/node_modules/ovsx/ /tmp/opt/
RUN tar -czf ovsx.tar.gz /tmp/opt/ovsx
RUN chmod g+rwX /opt/app-root/src/ovsx.tar.gz
