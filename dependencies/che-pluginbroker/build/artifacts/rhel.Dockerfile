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
FROM registry.access.redhat.com/rhel8/go-toolset:1.12 as builder
ENV PATH=/opt/rh/go-toolset-1.12/root/usr/bin:$PATH \
    GOPATH=/go/
USER root
WORKDIR /go/src/github.com/eclipse/che-plugin-broker/brokers/artifacts/cmd/
COPY . /go/src/github.com/eclipse/che-plugin-broker/
RUN adduser appuser && \
    dnf -y clean all && rm -rf /var/cache/yum && echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages" && \
    CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-w -s' -installsuffix cgo -o artifacts-broker main.go

# to test this container by attaching bash shell, need a non-scratch base like ubi8-minimal
# FROM registry.access.redhat.com/ubi8-minimal
FROM scratch

USER appuser
# CRW-528 copy actual cert
COPY --from=builder /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/ca-trust/extracted/pem/
# CRW-528 copy symlink to the above cert
COPY --from=builder /etc/pki/tls/certs/ca-bundle.crt                  /etc/pki/tls/certs/

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /go/src/github.com/eclipse/che-plugin-broker/brokers/artifacts/cmd/artifacts-broker /
ENTRYPOINT ["/artifacts-broker"]

# append Brew metadata here
