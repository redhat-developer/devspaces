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
${DNF} install -y findutils bash wget yum git gzip tar jq python3-six python3-pip skopeo --exclude=unbound-libs || exit 1

# shellcheck disable=SC2010
PYTHON_BIN=$(ls -1 /usr/bin | grep -E "^python3.[0-9]$" | sort -V | tail -1 || true) # 3.6, 3.7, 3.8, etc.
if [[ ! ${PYTHON_BIN} ]]; then
    PYTHON_BIN=$(/usr/bin/python3 -V | sed -r -e "s#Python ##" -e "s#([0-9])\.([0-9]+)\.([0-9]+)#\1.\2#")
    if [[ ! ${PYTHON_BIN} ]]; then
        PYTHON_BIN=$(/usr/bin/python -V | sed -r -e "s#Python ##" -e "s#([0-9])\.([0-9]+)\.([0-9]+)#\1.\2#")
    fi
fi
if [[ ! -L /usr/bin/python ]]; then
    ln -s /usr/bin/"${PYTHON_BIN}" /usr/bin/python
fi

# install yq (depends on jq and pyyaml - if jq and pyyaml not already installed, this will try to compile it)
if [[ -f /tmp/root-local.tgz ]] || [[ ${BOOTSTRAP} == "true" ]]; then
    mkdir -p /opt/app-root/src/.local
    if [[ -f /tmp/root-local.tgz ]]; then
        tar xf /tmp/root-local.tgz -C /opt/app-root/src/.local
        rm -fr /tmp/root-local.tgz
    fi
    /usr/bin/python -m pip install --user yq
    # NOTE: used to be in /root/.local but now can be found in /opt/app-root/src/.local
    # shellcheck disable=SC2043
    for d in /opt/app-root/src/.local; do
        if [[ -d ${d} ]]; then
            cp ${d}/bin/yq /usr/local/bin/
            mkdir -p ${d}/lib/"${PYTHON_BIN}"/site-packages/
            # shellcheck disable=SC2164
            pushd ${d}/lib/"${PYTHON_BIN}"/site-packages/ >/dev/null
            cp -r PyYAML* xmltodict* yaml* yq* /usr/lib/"${PYTHON_BIN}"/site-packages/
            # shellcheck disable=SC2164
            popd >/dev/null
        fi
    done
    chmod -c +x /usr/local/bin/*
else
    /usr/bin/python -m pip install yq
fi
# test install worked
for d in python yq jq; do echo -n "$d: "; $d --version; done

# for debugging only
# ${DNF} install -y util-linux && whereis python pip jq yq && python --version && jq --version && yq --version
