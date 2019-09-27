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
FROM registry.access.redhat.com/ubi8/nodejs-10:1-41
ENV SUMMARY="Red Hat CodeReady Workspaces - Theia-Dev container" \
    DESCRIPTION="Red Hat CodeReady Workspaces - Theia-Dev container" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="theia-dev-rhel8"

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

# enable rhel 7 or 8 content sets (from Brew) to resolve jq as rpm
COPY content_sets_epel7.repo /etc/yum.repos.d/

# TODO: this isn't available - do we need it? libxkbfile-devel
RUN dnf install -y microdnf curl jq make cmake gcc gcc-c++ python3-six git openssh less bash libX11-devel tar gzip && \
    dnf -y clean all && rm -rf /var/cache/yum && \
    # echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages" && \
    ln -s /usr/bin/python3.6 /usr/bin/python

# Add npm global bin directory to the path
ENV HOME=/home/theia-dev \
    PATH=/home/theia-dev/.npm-global/bin:${PATH} \
    # Specify the directory of git (avoid to search at init of Theia)
    USE_LOCAL_GIT=true \
    LOCAL_GIT_DIRECTORY=/usr \
    GIT_EXEC_PATH=/usr/libexec/git-core \
    THEIA_ELECTRON_SKIP_REPLACE_FFMPEG=true

# Define package of the theia generator to use - created in https://github.com/eclipse/che-theia/tree/master/dockerfiles/theia-dev
COPY generator/eclipse-che-theia-generator.tgz ${HOME}/eclipse-che-theia-generator.tgz

WORKDIR ${HOME}

# Exposing Theia ports
EXPOSE 3000 3030

# Configure npm and yarn to use home folder for global dependencies
RUN npm install -g yarn && \
    npm config set prefix "${HOME}/.npm-global" && \
    echo "--global-folder \"${HOME}/.yarn-global\"" > ${HOME}/.yarnrc && \
    # add eclipse che theia generator
    ## yarn global add yo @theia/generator-plugin@0.0.1-1540209403 file:${HOME}/eclipse-che-theia-generator.tgz && \
    yarn global add yo @theia/generator-plugin && \
    yarn global add @eclipse-che/theia-generator && \
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
