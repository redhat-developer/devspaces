# Copyright (c) 2018-2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift
FROM registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift:1.6-19.1553789890

ENV SUMMARY="Red Hat CodeReady Workspaces container that provides the Red Hat CodeReady Workspaces (Eclipse Che Server)" \
    DESCRIPTION="Red Hat CodeReady Workspaces container that provides the Red Hat CodeReady Workspaces (Eclipse Che Server)" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="server-container"

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Red Hat CodeReady Workspaces - Che Server" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME" \
      name="$PRODNAME/$COMPNAME" \
      version="1.3" \
      license="EPLv2" \
      maintainer="Nick Boldt <nboldt@redhat.com>" \
      io.openshift.expose-services="" \
      usage=""

USER root
# NOTE: uncomment to run a local build
#RUN subscription-manager register --username username --password password --auto-attach
#RUN subscription-manager repos --enable rhel-7-server-rpms -enable rhel-server-rhscl-7-rpms
COPY entrypoint.sh /entrypoint.sh
RUN mkdir -p /home/jboss/codeready

# NOTE: if built in Brew, use get-sources-jenkins.sh to pull latest
# OR, if you intend to build the Che Server tarball locally, 
# see https://github.com/redhat-developer/codeready-workspaces-productization/blob/master/devdoc/building/building-crw.adoc#make-changes-to-crw-and-re-deploy-to-minishift
# then copy /home/${USER}/projects/codeready-workspaces/assembly/codeready-workspaces-assembly-main/target/codeready-workspaces-assembly-main.tar.gz into this folder
COPY assembly/codeready-workspaces-assembly-main/target/codeready-workspaces-assembly-main.tar.gz /tmp/codeready-workspaces-assembly-main.tar.gz
RUN tar xzf /tmp/codeready-workspaces-assembly-main.tar.gz --strip-components=1 -C /home/jboss/codeready && \
    rm -f /tmp/codeready-workspaces-assembly-main.tar.gz && \
    cp /etc/pki/java/cacerts /home/jboss/cacerts && \
    mkdir -p /logs /data && \
    chgrp -R 0     /home/jboss /data /logs && \
    chmod -R g+rwX /home/jboss /data /logs && \
    yum list installed && echo "End Of Installed Packages"

USER jboss
ENTRYPOINT ["/entrypoint.sh"]
