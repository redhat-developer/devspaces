# Copyright (c) 2018-2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/ubi8/nodejs-10
FROM registry.access.redhat.com/ubi8/nodejs-10:1-51
ENV SUMMARY="Red Hat CodeReady Workspaces - Theia-Dev container" \
    DESCRIPTION="Red Hat CodeReady Workspaces - Theia-Dev container" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="theia-dev-rhel8" 
    # PATH=/opt/rh/rh-nodejs10/root/usr/bin:${PATH}

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
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

USER 0

# Alternate solution (eg., for using ubi7/nodejs-10 base image):
# 1. download these rpms
# https://rpmfind.net/linux/centos/7.7.1908/os/x86_64/Packages/libxkbfile-1.0.9-3.el7.x86_64.rpm
# https://rpmfind.net/linux/centos/7.7.1908/os/x86_64/Packages/libxkbfile-devel-1.0.9-3.el7.x86_64.rpm
# 2. COPY libxkbfile*.rpm /tmp/
# 3. RUN dnf install -y /tmp/libxkbfile*.rpm
# UBI8 versions exist on http://pulp-read.dist.prod.ext.phx2.redhat.com/content/dist/rhel8/8/x86_64/codeready-builder/os/
# Currently: libxkbfile-1.0.9-9.el8.x86_64 and libxkbfile-devel-1.0.9-9.el8.x86_64

# enable rhel8 content sets (including codeready-builder) to resolve jq and libxkbfile-devel + libxkbfile as rpms
COPY content_sets_rhel8.repo /etc/yum.repos.d/
RUN yum install -y curl jq make cmake gcc gcc-c++ python2 git openssh less bash libX11-devel tar gzip libxkbfile libxkbfile-devel && \
    yum -y clean all && rm -rf /var/cache/yum && \
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages" 

# Add npm global bin directory to the path
ENV HOME=/home/theia-dev \
    PATH=/home/theia-dev/.npm-global/bin:${PATH} \
    # Specify the directory of git (avoid to search at init of Theia)
    USE_LOCAL_GIT=true \
    LOCAL_GIT_DIRECTORY=/usr \
    GIT_EXEC_PATH=/usr/libexec/git-core \
    THEIA_ELECTRON_SKIP_REPLACE_FFMPEG=true

WORKDIR ${HOME}

# Exposing Theia ports
EXPOSE 3000 3030

# generator.tgz built from https://github.com/eclipse/che-theia/tree/master/generator
# DOWNSTREAM file must be in the root, not generator/ subfolder
COPY eclipse-che-theia-generator.tgz ${HOME}/eclipse-che-theia-generator.tgz

# 0. Enable this script to collect intalled node deps into a single folder for easier tarballing
COPY collect.installed.dependencies.sh /usr/local/bin/

# 1. extract files in the container to your local filesystem
# CONTAINERNAME="quay.io/crw/crw-theia-dev:next" && rm -f root-local.tgz && ./build.sh
# mkdir -p /tmp/root-local/ && docker run --rm -v /tmp/root-local/:/tmp/root-local/ ${CONTAINERNAME} /bin/bash -c "collect.installed.dependencies.sh"
# pushd /tmp/root-local >/dev/null && sudo tar czf /tmp/root-local.tgz ./* && popd >/dev/null && sudo mv -f /tmp/root-local.tgz . && sudo rm -fr /tmp/root-local/

# 2. then add it to dist-git so it's part of this repo
#    rhpkg new-sources root-local.tgz 

# 3. built in Brew, use tarball in lookaside cache; built locally, comment this out
# COPY root-local.tgz /tmp/root-local.tgz

# Configure npm and yarn to use home folder for global dependencies
RUN whereis npm node && node --version && npm --version && \
    if [[ ! -f /tmp/root-local.tgz ]]; then \
        # online install
        npm install -g yarn && \
        npm config set prefix "${HOME}/.npm-global" && \
        echo "--global-folder \"${HOME}/.yarn-global\"" > ${HOME}/.yarnrc && \
        # add eclipse che theia generator
        yarn global add yo @theia/generator-plugin@0.0.1-1562578105 file:${HOME}/eclipse-che-theia-generator.tgz; \
    else \
        npm config set prefix "${HOME}/.npm-global" && \
        echo "--global-folder \"${HOME}/.yarn-global\"" > ${HOME}/.yarnrc && \
        # offline install (Brew)
        tar xf /tmp/root-local.tgz -C /; rm -fr /tmp/root-local.tgz; \
    fi; \
    echo -n "yarn " && yarn --version && \
    echo -n "che:theia " && che:theia --version && \
    # Generate .passwd.template \
    cat /etc/passwd | \
    sed s#root:x.*#theia-dev:x:\${USER_ID}:\${GROUP_ID}::${HOME}:/bin/bash#g \
    > ${HOME}/.passwd.template && \
    # Generate .group.template \
    cat /etc/group | \
    sed s#root:x:0:#root:x:0:0,\${USER_ID}:#g \
    > ${HOME}/.group.template && \
    mkdir /projects && \
    # Define default prompt
    echo "export PS1='\[\033[01;33m\](\u@container)\[\033[01;36m\] (\w) \$ \[\033[00m\]'" > ${HOME}/.bashrc  && \
    # Disable the statistics for yeoman
    mkdir -p ${HOME}/.config/insight-nodejs/ && \
    echo '{"optOut": true}' > ${HOME}/.config/insight-nodejs/insight-yo.json && \
    # Change permissions to let any arbitrary user
    for f in "${HOME}" "/etc/passwd" "/etc/group" "/projects"; do \
        echo "Changing permissions on ${f}" && chgrp -R 0 ${f} && \
        chmod -R g+rwX ${f}; \
    done && \
    echo "Installed npm Packages" && npm ls -g | sort | uniq && yarn global list && \
    echo "End Of Installed npm Packages"

WORKDIR /projects

ADD src/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD tail -f /dev/null
