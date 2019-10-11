#!/bin/bash
#
# Copyright (c) 2012-2018 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

microdnf install -y findutils bash wget yum gzip tar jq python3-six python3-pip && microdnf -y clean all && \
# install yq (depends on jq and pyyaml - if jq and pyyaml not already installed, this will try to compile it)
if [[ -f /tmp/root-local.tgz ]] || [[ ${BOOTSTRAP} == "true" ]]; then \
    mkdir -p /root/.local; tar xf /tmp/root-local.tgz -C /root/.local/; rm -fr /tmp/root-local.tgz;  \
    /usr/bin/pip3.6 install --user yq jsonschema; \
    # could be installed in /opt/app-root/src/.local/bin or /root/.local/bin
    for d in /opt/app-root/src/.local /root/.local; do \
    if [[ -d ${d} ]]; then \
        cp ${d}/bin/yq ${d}/bin/jsonschema /usr/local/bin/; \
        pushd ${d}/lib/python3.6/site-packages/ >/dev/null; \
        cp -r PyYAML* xmltodict* yaml* yq* jsonschema* /usr/lib/python3.6/site-packages/; \
        popd >/dev/null; \
    fi; \
    done; \
    chmod -c +x /usr/local/bin/*; \
else \
    /usr/bin/pip3.6 install yq jsonschema; \
fi && \
ln -s /usr/bin/python3.6 /usr/bin/python && \
# test install worked
for d in python yq jq jsonschema; do echo -n "$d: "; $d --version; done

# for debugging only
# microdnf install -y util-linux && whereis python pip jq yq && python --version && jq --version && yq --version
