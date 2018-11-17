# Copyright (c) 2018 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

FROM registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift:1.5-14
# FROM redhat-openjdk-18/openjdk18-openshift:1.5-14

ENV SUMMARY="Red Hat CodeReady Workspaces container that provides the Red Hat CodeReady Workspaces (Eclipse Che Server)" \
    DESCRIPTION="Red Hat CodeReady Workspaces container that provides the Red Hat CodeReady Workspaces (Eclipse Che Server)" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="container"

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Red Hat CodeReady Workspaces for OpenShift - Che Server" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME" \
      name="$PRODNAME/$COMPNAME" \
      version="1.0.0.Beta1" \
      license="EPLv2" \
      maintainer="Nick Boldt <nboldt@redhat.com>" \
      io.openshift.expose-services="" \
      usage=""

USER root
COPY entrypoint.sh /entrypoint.sh
RUN mkdir -p /home/jboss/codeready

# built locally, use ADD
ADD assembly/codeready-workspaces-assembly-main/target/codeready-6.14.1-SNAPSHOT/codeready-6.14.1-SNAPSHOT /home/jboss/codeready

# built in Brew, use curl + tar against latest artifact
# fetched via fetch-artifacts-url.yaml?
# RUN curl -L -s -S http://download-ipv4.eng.brq.redhat.com/brewroot/packages/com.redhat-codeready/1.0.0.Beta1_redhat_00002/1/maven/com/redhat/assembly-main/6.13.0.redhat-00002/assembly-main-6.13.0.redhat-00002.tar.gz > \
#         /tmp/com.redhat-codeready-assembly-main.tar.gz
# RUN tar xzf /tmp/com.redhat-codeready-assembly-main.tar.gz --strip-components=1 -C /home/jboss/codeready

RUN mkdir -p /logs /data && \
    chgrp -R 0     /home/jboss /data /logs && \
    chmod -R g+rwX /home/jboss /data /logs

USER jboss
ENTRYPOINT ["/entrypoint.sh"]
