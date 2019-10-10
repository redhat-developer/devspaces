#
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

# Builder: check meta.yamls and create index.json
# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/ubi8-minimal
FROM registry.access.redhat.com/ubi8-minimal:8.0-213 as builder
USER 0

################# 
# PHASE ONE: create ubi8-minimal image with yq
################# 

ARG BOOTSTRAP=false
ENV BOOTSTRAP=${BOOTSTRAP}
ARG LATEST_ONLY=false
ENV LATEST_ONLY=${LATEST_ONLY}

# to get all the python deps pre-fetched so we can build in Brew:
# 1. extract files in the container to your local filesystem
#    find v3 -type f -exec dos2unix {} \;
#    CONTAINERNAME="devfileregistrybuilder" && docker build -t ${CONTAINERNAME} . --target=builder --no-cache --squash --build-arg BOOTSTRAP=true
#    mkdir -p /tmp/root-local/ && docker run -it -v /tmp/root-local/:/tmp/root-local/ ${CONTAINERNAME} /bin/bash -c "cd /root/.local/ && cp -r bin/ lib/ /tmp/root-local/"
#    pushd /tmp/root-local >/dev/null && sudo tar czf root-local.tgz lib/ bin/ && popd >/dev/null && mv -f /tmp/root-local/root-local.tgz . && sudo rm -fr /tmp/root-local/

# 2. then add it to dist-git so it's part of this repo
#    rhpkg new-sources root-local.tgz 

# built in Brew, use tarball in lookaside cache; built locally, comment this out
# COPY root-local.tgz /tmp/root-local.tgz

# NOTE: uncomment for local build. Must also set full registry path in FROM to registry.redhat.io or registry.access.redhat.com
# enable rhel 7 or 8 content sets (from Brew) to resolve jq as rpm
COPY /build/dockerfiles/content_sets_epel7.repo /etc/yum.repos.d/

RUN microdnf install -y findutils bash wget yum gzip tar jq python3-six python3-pip && microdnf -y clean all && \
    # install yq (depends on jq and pyyaml - if jq and pyyaml not already installed, this will try to compile it)
    if [[ -f /tmp/root-local.tgz ]] || [[ ${BOOTSTRAP} == "true" ]]; then \
      mkdir -p /root/.local; tar xf /tmp/root-local.tgz -C /root/.local/; rm -fr /tmp/root-local.tgz;  \
      /usr/bin/pip3.6 install --user yq jsonschema; \
      # could be installed in /opt/app-root/src/.local/bin or /root/.local/bin
      for d in /opt/app-root/src/.local /root/.local; do \
        if [[ -d ${d} ]]; then \
          cp ${d}/bin/yq ${d}/bin/jsonschema /usr/local/bin/; \
          pushd ${d}/lib/python3.6/site-packages/ >/dev/null; \
            cp -r PyYAML* xmltodict* yaml* yq* jsonschema* /usr/lib/python3.6/site-packages/; \
          popd >/dev/null; \
        fi; \
      done; \
      chmod -c +x /usr/local/bin/*; \
    else \
      /usr/bin/pip3.6 install yq jsonschema; \
    fi && \
    ln -s /usr/bin/python3.6 /usr/bin/python && \
    # test install worked
    for d in python yq jq jsonschema; do echo -n "$d: "; $d --version; done

# for debugging only
# RUN microdnf install -y util-linux && whereis python pip jq yq && python --version && jq --version && yq --version

# Registry, organization, and tag to use for base images in dockerfiles. Devfiles
# will be rewritten during build to use these values for base images.
ARG PATCHED_IMAGES_REG="quay.io"
ARG PATCHED_IMAGES_ORG="crw"
ARG PATCHED_IMAGES_TAG="2.0"

COPY /build/scripts /arbitrary-users-patch/base_images /build/
COPY /devfiles /build/devfiles
WORKDIR /build/
RUN TAG=${PATCHED_IMAGES_TAG} \
    ORGANIZATION=${PATCHED_IMAGES_ORG} \
    REGISTRY=${PATCHED_IMAGES_REG} \
    ./update_devfile_patched_image_tags.sh
RUN ./check_mandatory_fields.sh devfiles
RUN ./index.sh > /build/devfiles/index.json

################# 
# PHASE TWO: configure registry image
################# 

# Build registry, copying meta.yamls and index.json from builder
# UPSTREAM: use RHEL7/RHSCL/httpd image so we're not required to authenticate with registry.redhat.io
# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/rhscl/httpd-24-rhel7
# FROM registry.access.redhat.com/rhscl/httpd-24-rhel7:2.4-104 AS registry

# DOWNSTREAM: use RHEL8/httpd
# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/rhel8/httpd-24
FROM registry.redhat.io/rhel8/httpd-24:1-60 AS registry
USER 0

# BEGIN these steps might not be required
RUN sed -i /etc/httpd/conf/httpd.conf \
    -e "s,Listen 80,Listen 8080," \
    -e "s,logs/error_log,/dev/stderr," \
    -e "s,logs/access_log,/dev/stdout," \
    -e "s,AllowOverride None,AllowOverride All," && \
    chmod a+rwX /etc/httpd/conf /run/httpd
STOPSIGNAL SIGWINCH
# END these steps might not be required

RUN mkdir /var/www/html/devfiles
COPY .htaccess README.md /var/www/html/
COPY --from=builder /build/devfiles /var/www/html/devfiles
RUN chmod -R g+rwX /var/www/html/devfiles
COPY /build/scripts/*entrypoint.sh /usr/local/bin/

WORKDIR /var/www/html
ENTRYPOINT ["/usr/local/bin/uid_entrypoint.sh", "/usr/local/bin/entrypoint.sh"]

# append Brew metadata here
