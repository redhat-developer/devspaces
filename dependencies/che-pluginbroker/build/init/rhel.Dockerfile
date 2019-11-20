# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/rhel8/go-toolset
FROM registry.access.redhat.com/rhel8/go-toolset:1.11.13-18 as builder
ENV PATH=/opt/rh/go-toolset-1.11/root/usr/bin:$PATH \
    GOPATH=/go/
USER root
WORKDIR /go/src/github.com/eclipse/che-plugin-broker/brokers/init/cmd/
COPY . /go/src/github.com/eclipse/che-plugin-broker/
# Workaround for CRW-494 - disable websocket communication in init broker
RUN LN_START="$(grep -n 'cfg.DisablePushingToEndpoint' main.go | cut -f 1 -d ':')"; \
    LN_END="$((LN_START + 3))"; \
    sed -i "${LN_START},${LN_END}s|^|//|g" main.go && \
    echo "Updated main.go" && cat main.go
# End Workaround for CRW-494

RUN adduser appuser && \
    CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-w -s' -installsuffix cgo -o init-plugin-broker main.go

FROM scratch

USER appuser
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /go/src/github.com/eclipse/che-plugin-broker/brokers/init/cmd/init-plugin-broker /
ENTRYPOINT ["/init-plugin-broker"]

ENV SUMMARY="Red Hat CodeReady Workspaces pluginbroker init container" \
    DESCRIPTION="Red Hat CodeReady Workspaces pluginbroker init container" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="pluginbrokerinit-rhel8"
LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \s
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="$DESCRIPTION" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME-container" \
      name="$PRODNAME/$COMPNAME" \
      version="2.0" \
      license="EPLv2" \
      maintainer="Nick Boldt <nboldt@redhat.com>" \
      io.openshift.expose-services="" \
      usage=""
