# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

FROM registry.access.redhat.com/ubi8/ubi:8.6-943 as builder

RUN yum install java-11-openjdk-devel git jq curl -y --nodocs

RUN cd /tmp && \
    git clone https://github.com/che-incubator/che-openvsx.git && \
    cd che-openvsx/server && \
    git checkout che-openvsx

RUN cd /tmp/che-openvsx/server && ./gradlew --no-daemon assemble

RUN mkdir /openvsx-server && \
    cp /tmp/che-openvsx/server/scripts/run-server.sh /openvsx-server && \
    cp /tmp/che-openvsx/server/build/libs/openvsx-server.jar /openvsx-server

RUN cd /openvsx-server && jar -xf openvsx-server.jar && rm openvsx-server.jar

# Pull vsix files from openvsx
COPY /openvsx-sync.json /openvsx-server/
COPY /build/scripts/download_vsix.sh /tmp
RUN /tmp/download_vsix.sh && mv /tmp/vsix /openvsx-server

RUN tar -czvf openvsx-server.tar.gz openvsx-server \
