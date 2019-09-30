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
FROM registry.access.redhat.com/ubi7/nodejs-10:1-20.1568971390
ENV SUMMARY="Red Hat CodeReady Workspaces - Theia-Dev container" \
    DESCRIPTION="Red Hat CodeReady Workspaces - Theia-Dev container" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="theia-dev" \
    PATH=/opt/rh/rh-nodejs10/root/usr/bin:${PATH}

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

USER root

# Alternate solution (eg., for using ubi8 base image, where no el8 versions exist):
# 1. download these rpms
# https://rpmfind.net/linux/centos/7.7.1908/os/x86_64/Packages/libxkbfile-1.0.9-3.el7.x86_64.rpm
# https://rpmfind.net/linux/centos/7.7.1908/os/x86_64/Packages/libxkbfile-devel-1.0.9-3.el7.x86_64.rpm
# 2. COPY libxkbfile*.rpm /tmp/
# 3. RUN dnf install -y /tmp/libxkbfile*.rpm

# enable rhel 7 (or 8) content sets to resolve jq and libxkbfile-devel + libxkbfile as rpms
COPY content_sets_epel7.repo /etc/yum.repos.d/
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
COPY generator/eclipse-che-theia-generator.tgz ${HOME}/eclipse-che-theia-generator.tgz

# Configure npm and yarn to use home folder for global dependencies
RUN whereis npm node && node --version && npm --version && \
    npm install -g yarn && \
    npm config set prefix "${HOME}/.npm-global" && \
    echo "--global-folder \"${HOME}/.yarn-global\"" > ${HOME}/.yarnrc && \
    # yarn global add yo @theia/generator-plugin@0.0.1-1540209403 file:${HOME}/eclipse-che-theia-generator.tgz && \
    # theia plugin generator from https://github.com/eclipse/theia-generator-plugin
    yarn global add yo @theia/generator-plugin && \
    yarn global add file:${HOME}/eclipse-che-theia-generator.tgz && \
    # or use latest release :: yarn global add @eclipse-che/theia-generator && \
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

# TODO: collect all these freshly installed npm deps into a tarball for reuse in Brew
#   /home/theia-dev/.yarn-global/node_modules/ 
#   /usr/local/share/.cache/yarn/
#   /opt/app-root/src/.npm-global/

WORKDIR /projects

ADD src/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD tail -f /dev/null
