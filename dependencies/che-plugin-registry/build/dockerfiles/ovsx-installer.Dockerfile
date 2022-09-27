# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

FROM registry.access.redhat.com/ubi8/python-38:1-100 as builder
USER 0

ENV PATH="/tmp/opt/nodejs/bin:$PATH" \
    npm_config_cache=/tmp/opt/cache

RUN yum install curl -y --nodocs

USER 1001

RUN mkdir -p /tmp/opt/nodejs && mkdir -p /tmp/otp/cache &&\
    curl -sL https://nodejs.org/download/release/v16.17.1/node-v16.17.1-linux-x64.tar.gz | tar xzf - -C /tmp/opt/nodejs --strip-components=1

# install the ovsx cli
RUN npm install -g ovsx@0.5.0 && chmod -R g+rwX /tmp/opt/nodejs
RUN tar -czvf nodejs.tar.gz /tmp/opt/nodejs
RUN chmod g+rwX /opt/app-root/src/nodejs.tar.gz
