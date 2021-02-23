#!/bin/bash
#
# Copyright (c) 2018-2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
set -x

DNF=dnf
if [[ ! -x $(command -v $DNF || true) ]]; then   DNF=yum
  if [[ ! -x $(command -v $DNF || true) ]]; then DNF=microdnf; fi
fi

# workaround for performance issues in CRW-1610
echo "[main]
gpgcheck=0
installonly_limit=3
clean_requirements_on_remove=True
best=True
skip_if_unavailable=True
fastestmirror=True
max_parallel_downloads=10
minrate=1
retries=20
timeout=60
" > /etc/yum.conf 
${DNF} install -y drpm dnf || exit 1 # enable delta rpms
# note: one of these requires python 3.6 (not 3.8)
dnf install -y findutils bash wget yum git gzip tar jq python3-six python3-pip skopeo || exit 1
# install yq (depends on jq and pyyaml - if jq and pyyaml not already installed, this will try to compile it)
ln -s /usr/bin/python3.6 /usr/bin/python
if [[ -f /tmp/root-local.tgz ]] || [[ ${BOOTSTRAP} == "true" ]]; then
    mkdir -p /root/.local
    if [[ -f /tmp/root-local.tgz ]]; then
        tar xf /tmp/root-local.tgz -C /root/.local/
        rm -fr /tmp/root-local.tgz
    fi
    /usr/bin/python -m pip install --user yq jsonschema
    # could be installed in /opt/app-root/src/.local/bin or /root/.local/bin
    for d in /opt/app-root/src/.local /root/.local; do
        if [[ -d ${d} ]]; then
            cp ${d}/bin/yq ${d}/bin/jsonschema /usr/local/bin/
            pushd ${d}/lib/python3.6/site-packages/ >/dev/null
            cp -r PyYAML* xmltodict* yaml* yq* jsonschema* /usr/lib/python3.6/site-packages/
            popd >/dev/null
        fi
    done
    chmod -c +x /usr/local/bin/*
else
    /usr/bin/python -m pip install yq jsonschema
fi
# test install worked
for d in python yq jq jsonschema; do echo -n "$d: "; $d --version; done

# for debugging only
# ${DNF} install -y util-linux && whereis python pip jq yq && python --version && jq --version && yq --version
