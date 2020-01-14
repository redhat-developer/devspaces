# Copyright (c) 2019-2020 Red Hat, Inc.
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
FROM registry.access.redhat.com/rhel8/go-toolset:1.12.8-18 as builder
ENV PATH=/opt/rh/go-toolset-1.11/root/usr/bin:$PATH \
    GOPATH=/go/
USER root
WORKDIR /go/src/github.com/eclipse/che-plugin-broker/brokers/init/cmd/
COPY . /go/src/github.com/eclipse/che-plugin-broker/
RUN adduser appuser && \
    dnf -y clean all && rm -rf /var/cache/yum && \
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages" && \
    CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-w -s' -installsuffix cgo -o init-plugin-broker main.go

# to test this container by attaching bash shell, need a non-scratch base like ubi8-minimal
# FROM registry.access.redhat.com/ubi8-minimal
FROM scratch

USER appuser
# CRW-528 copy actual cert
COPY --from=builder /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/ca-trust/extracted/pem/
# CRW-528 copy symlink to the above cert
COPY --from=builder /etc/pki/tls/certs/ca-bundle.crt                  /etc/pki/tls/certs/

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /go/src/github.com/eclipse/che-plugin-broker/brokers/init/cmd/init-plugin-broker /
ENTRYPOINT ["/init-plugin-broker"]

ENV SUMMARY="Red Hat CodeReady Workspaces pluginbroker init container" \
    DESCRIPTION="Red Hat CodeReady Workspaces pluginbroker init container" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="pluginbrokerinit-rhel8"
LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="$DESCRIPTION" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME-container" \
      name="$PRODNAME/$COMPNAME" \
      version="2.1" \
      license="EPLv2" \
      maintainer="Nick Boldt <nboldt@redhat.com>" \
      io.openshift.expose-services="" \
      usage=""
