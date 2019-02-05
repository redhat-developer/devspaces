# Copyright (c) 2018 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift
FROM redhat-openjdk-18/openjdk18-openshift:1.5-14.1539812388

ENV SUMMARY="Red Hat CodeReady Workspaces container that provides the Red Hat CodeReady Workspaces (Eclipse Che Server)" \
    DESCRIPTION="Red Hat CodeReady Workspaces container that provides the Red Hat CodeReady Workspaces (Eclipse Che Server)" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="server-container"

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Red Hat CodeReady Workspaces for OpenShift - Che Server" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME" \
      name="$PRODNAME/$COMPNAME" \
      version="1.0" \
      license="EPLv2" \
      maintainer="Nick Boldt <nboldt@redhat.com>" \
      io.openshift.expose-services="" \
      usage=""

# uncomment to run a local build
#RUN subscription-manager register --username username --password password --auto-attach
#RUN subscription-manager repos --enable rhel-7-server-optional-rpms -enable rhel-server-rhscl-7-rpms

USER root
COPY entrypoint.sh /entrypoint.sh
RUN mkdir -p /home/jboss/codeready

# built in Brew, use get-sources.sh to pull latest
COPY codeready-workspaces-assembly-main.tar.gz /tmp/codeready-workspaces-assembly-main.tar.gz
RUN tar xzf /tmp/codeready-workspaces-assembly-main.tar.gz --strip-components=1 -C /home/jboss/codeready && \
    rm -f /tmp/codeready-workspaces-assembly-main.tar.gz && \
    cp /etc/pki/java/cacerts /home/jboss/cacerts && \
    mkdir -p /logs /data && \
    chgrp -R 0     /home/jboss /data /logs && \
    chmod -R g+rwX /home/jboss /data /logs && \
    yum list installed && echo "End Of Installed Packages"

USER jboss
ENTRYPOINT ["/entrypoint.sh"]
