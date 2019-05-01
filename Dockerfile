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

# TODO: switch to RHEL 8 based openjdk or EAP 7.2.1/7.3
# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift
FROM registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift:1.6-20

ENV SUMMARY="Red Hat CodeReady Workspaces Server container" \
    DESCRIPTION="Red Hat CodeReady Workspaces server container" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="server-rhel8"

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="$DESCRIPTION" \
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
# CVE fix for RHSA-2019:0679-02 https://pipeline.engineering.redhat.com/freshmakerevent/8717
# CVE-2019-9636 errata 40636 - update python and python-libs to 2.7.5-77.el7_6
# cannot apply CVEs when using -rhel8 suffix as yum will try to resolve .el8 rpms # RUN yum update -y libssh2 python-libs python java-1.8.0-openjdk java-1.8.0-openjdk-devel java-1.8.0-openjdk-headless && yum updateinfo list && 
RUN yum clean all && rm -rf /var/cache/yum && \
    tar xzf /tmp/codeready-workspaces-assembly-main.tar.gz --strip-components=1 -C /home/jboss/codeready && \
    rm -f /tmp/codeready-workspaces-assembly-main.tar.gz && \
    cp /etc/pki/java/cacerts /home/jboss/cacerts && \
    mkdir -p /logs /data && \
    chgrp -R 0     /home/jboss /data /logs && \
    chmod -R g+rwX /home/jboss /data /logs && \
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages"

USER jboss
ENTRYPOINT ["/entrypoint.sh"]
