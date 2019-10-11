# Copyright (c) 2018-2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

###
# Builder Image
#
FROM quay.io/crw/theia-dev-rhel8:2.0 as builder
# FROM registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-theia-dev-rhel8:2.0 as builder

WORKDIR ${HOME}

# Export GITHUB_TOKEN into environment variable
ARG GITHUB_TOKEN=''
ENV GITHUB_TOKEN=$GITHUB_TOKEN

ARG THEIA_GITHUB_REPO=eclipse-theia/theia

# Define upstream version of theia to use
ARG THEIA_VERSION=master

ENV NODE_OPTIONS="--max-old-space-size=4096" \
    YARN_FLAGS="--offline"

# Clone theia
COPY asset-theia-source-code.tar.gz /tmp/asset-theia-source-code.tar.gz
RUN tar xzf /tmp/asset-theia-source-code.tar.gz -C ${HOME} && rm -f /tmp/asset-theia-source-code.tar.gz
# patch electron module by removing native keymap module (no need to have some X11 libraries)
RUN line_to_delete=$(grep -n native-keymap ${HOME}/theia-source-code/dev-packages/electron/package.json | cut -d ":" -f 1) && \
    sed -i -e "${line_to_delete},1d" ${HOME}/theia-source-code/dev-packages/electron/package.json

# Add patches
ADD src/patches ${HOME}/patches

# Apply patches
RUN if [ -d "${HOME}/patches/${THEIA_VERSION}" ]; then \
      echo "Applying patches for Theia version ${THEIA_VERSION}"; \
      for file in $(find "${HOME}/patches/${THEIA_VERSION}" -name '*.patch'); do \
        echo "Patching with ${file}"; \
        cd ${HOME}/theia-source-code && patch -p1 < ${file}; \
      done \
    fi

# Generate che-theia
ARG CDN_PREFIX=""
ARG MONACO_CDN_PREFIX=""
WORKDIR ${HOME}/theia-source-code

COPY asset-che-theia.tar.gz asset-yarn.tar.gz asset-post-download-dependencies.tar.gz asset-moxios.tgz /tmp/

# Add che-theia repository content
# NOTE: this tarball is NOT gzipped despite the filename. Don't believe the lies!
RUN mkdir -p ${HOME}/theia-source-code/che-theia/ && tar xf /tmp/asset-che-theia.tar.gz -C ${HOME}/theia-source-code/che-theia/ && rm /tmp/asset-che-theia.tar.gz

# run che:theia init command and alias che-theia repository to use local sources insted of cloning
RUN che:theia init -c ${HOME}/theia-source-code/che-theia/che-theia-init-sources.yml --alias https://github.com/eclipse/che-theia=${HOME}/theia-source-code/che-theia

RUN che:theia cdn --theia="${CDN_PREFIX}" --monaco="${MONACO_CDN_PREFIX}"

# Compile Theia
RUN tar xzf /tmp/asset-yarn.tar.gz -C / && rm -f /tmp/asset-yarn.tar.gz && \
    tar xzf /tmp/asset-post-download-dependencies.tar.gz -C / && rm -f /tmp/asset-post-download-dependencies.tar.gz

COPY asset-node-headers.tar.gz ${HOME}/asset-node-headers.tar.gz

# Copy yarn.lock to be the same than the previous build
COPY asset-yarn.lock ${HOME}/theia-source-code/yarn.lock

# expand artifact
RUN mkdir -p /tmp/moxios && tar xzf /tmp/asset-moxios.tgz -C /tmp/moxios && rm -f /tmp/asset-moxios.tgz

RUN \
    # Define node headers
    npm config set tarball ${HOME}/asset-node-headers.tar.gz && \
    # Disable travis script
    echo "#!/usr/bin/env node" > /home/theia-dev/theia-source-code/scripts/prepare-travis \
    # Patch github link to a local link 
    && sed -i -e 's|moxios "git://github.com/stoplightio/moxios#v1.3.0"|moxios "file:///tmp/moxios"|' ${HOME}/theia-source-code/yarn.lock \
    && sed -i -e "s|git://github.com/stoplightio/moxios#v1.3.0|file:///tmp/moxios|" ${HOME}/theia-source-code/yarn.lock \
    # Add offline mode in examples
    && sed -i -e "s|spawnSync('yarn', \[\]|spawnSync('yarn', \['--offline'\]|" ${HOME}/theia-source-code/plugins/foreach_yarn \
    # Disable automatic tests that connect online
    && sed -i -e "s/ && yarn test//" plugins/factory-plugin/package.json 

# Unset GITHUB_TOKEN environment variable if it is empty.
# This is needed for some tools which use this variable and will fail with 401 Unauthorized error if it is invalid.
# For example, vscode ripgrep downloading is an example of such case.
RUN if [ -z $GITHUB_TOKEN ]; then unset GITHUB_TOKEN; fi && \
    yarn ${YARN_FLAGS}

# Run into production mode
RUN sed -i -e 's|moxios "git://github.com/stoplightio/moxios#v1.3.0"|moxios "file:///tmp/moxios"|' ${HOME}/theia-source-code/yarn.lock
RUN che:theia production

# Compile plugins
RUN if [ -z $GITHUB_TOKEN ]; then unset GITHUB_TOKEN; fi && \
    cd plugins && ./foreach_yarn

# Add yeoman generator & vscode git plug-ins
COPY asset-untagged-c11870b25a17d20bb7a7-theia_yeoman_plugin.theia /default-theia-plugins/theia_yeoman_plugin.theia
COPY asset-vscode-git-1.3.0.1.vsix /default-theia-plugins/vscode-git-1.3.0.1.vsix

# change permissions
RUN find production -exec sh -c "chgrp 0 {}; chmod g+rwX {}" \; 2>log.txt


###
# Runtime Image
#

# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/ubi8/nodejs-10
FROM registry.access.redhat.com/ubi8/nodejs-10:1-51

ENV USE_LOCAL_GIT=true \
    HOME=/home/theia \
    THEIA_DEFAULT_PLUGINS=local-dir:///default-theia-plugins \
    # Specify the directory of git (avoid to search at init of Theia)
    LOCAL_GIT_DIRECTORY=/usr \
    GIT_EXEC_PATH=/usr/libexec/git-core \
    # Ignore from port plugin the default hosted mode port
    PORT_PLUGIN_EXCLUDE_3130=TRUE \
    YARN_FLAGS="--offline"

ENV SUMMARY="Red Hat CodeReady Workspaces - Theia container" \
    DESCRIPTION="Red Hat CodeReady Workspaces - Theia container" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="theia-rhel8" 

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

EXPOSE 3100 3130

COPY --from=builder /home/theia-dev/theia-source-code/production/plugins /default-theia-plugins

# need root user
USER root

# Install sudo
# Install git
# Install bzip2 to unpack files
# Install which tool in order to search git
# Install curl and bash
# Install ssh for cloning ssh-repositories
# Install less for handling git diff properly
RUN yum install -y sudo git bzip2 which bash curl openssh less && \
    yum -y clean all && rm -rf /var/cache/yum && \
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages" 

# setup yarn (if missing)
# Include yarn assets for runtime image
COPY asset-yarn-runtime-image.tar.gz /tmp/
RUN tar xzf /tmp/asset-yarn-runtime-image.tar.gz -C / && rm -f /tmp/asset-yarn-runtime-image.tar.gz && \
    adduser -r -u 1002 -G root -d ${HOME} -m -s /bin/sh theia \
    && echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    # Create /projects for Che
    && mkdir /projects \
    # Create root node_modules in order to not use node_modules in each project folder
    && mkdir /node_modules \
    && for f in "${HOME}" "/etc/passwd" "/etc/group /node_modules /default-theia-plugins /projects"; do\
           sudo chgrp -R 0 ${f} && \
           sudo chmod -R g+rwX ${f}; \
       done \
    && cat /etc/passwd | sed s#root:x.*#root:x:\${USER_ID}:\${GROUP_ID}::\${HOME}:/bin/bash#g > ${HOME}/passwd.template \
    && cat /etc/group | sed s#root:x:0:#root:x:0:0,\${USER_ID}:#g > ${HOME}/group.template \
    # Add yeoman, theia plugin generator and typescript (to have tsc/typescript working)
    && yarn cache dir \
    && yarn global add ${YARN_FLAGS} yo @theia/generator-plugin@0.0.1-1562578105 typescript@2.9.2 \
    && mkdir -p ${HOME}/.config/insight-nodejs/ \
    && chmod -R 777 ${HOME}/.config/ \
    # Disable the statistics for yeoman
    && echo '{"optOut": true}' > $HOME/.config/insight-nodejs/insight-yo.json \
    #{IF:DO_CLEANUP}
    # Link yarn global modules for yeoman
    && local_modules=$(ls -d1 /usr/*/node_modules 2>/dev/null || ls -d1 /usr/*/*/node_modules) \
    && mv ${local_modules}/* /usr/local/share/.config/yarn/global/node_modules && rm -rf ${local_modules} && ln -s /usr/local/share/.config/yarn/global/node_modules $(dirname ${local_modules})/ \
    # Cleanup tmp folder
    && rm -rf /tmp/* \
    # Cleanup yarn cache
    && yarn cache clean \
    #ENDIF
    # Change permissions to allow editing of files for openshift user
    && find ${HOME} -exec sh -c "chgrp 0 {}; chmod g+rwX {}" \;

COPY --chown=theia:root --from=builder /home/theia-dev/theia-source-code/production /home/theia
USER theia
WORKDIR /projects
COPY src/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
