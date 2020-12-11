#
# Copyright (c) 2018-2020 Red Hat, Inc.
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
FROM registry.access.redhat.com/ubi8-minimal:8.3-201 as builder
USER 0

################# 
# PHASE ONE: create ubi8-minimal image with yq
################# 

ARG BOOTSTRAP=false
ENV BOOTSTRAP=${BOOTSTRAP}
ARG USE_DIGESTS=false
ENV USE_DIGESTS=${USE_DIGESTS}

# to get all the python deps pre-fetched so we can build in Brew:
# 1. extract files in the container to your local filesystem
#    find v3 -type f -exec dos2unix {} \;
#    CONTAINERNAME="tmpregistrybuilder" && docker build -t ${CONTAINERNAME} . --target=builder --no-cache --squash --build-arg BOOTSTRAP=true
#    mkdir -p /tmp/root-local/ && docker run -it -v /tmp/root-local/:/tmp/root-local/ ${CONTAINERNAME} /bin/bash -c "cd /root/.local/ && cp -r bin/ lib/ /tmp/root-local/"
#    pushd /tmp/root-local >/dev/null && sudo tar czf root-local.tgz lib/ bin/ && popd >/dev/null && mv -f /tmp/root-local/root-local.tgz . && sudo rm -fr /tmp/root-local/

# 2. then add it to dist-git so it's part of this repo
#    rhpkg new-sources root-local.tgz 

# built in Brew, use tarball in lookaside cache; built locally, comment this out
# COPY root-local.tgz /tmp/root-local.tgz

# NOTE: uncomment for local build. Must also set full registry path in FROM to registry.redhat.io or registry.access.redhat.com
# enable rhel 7 or 8 content sets (from Brew) to resolve jq as rpm
COPY ./build/dockerfiles/content_set*.repo /etc/yum.repos.d/
COPY ./build/dockerfiles/rhel.install.sh /tmp
RUN /tmp/rhel.install.sh && rm -f /tmp/rhel.install.sh

COPY ./build/scripts ./arbitrary-users-patch/base_images /build/
COPY ./devfiles /build/devfiles
WORKDIR /build/

# Registry, organization, and tag to use for base images in dockerfiles. Devfiles
# will be rewritten during build to use these values for base images.
ARG PATCHED_IMAGES_REG="quay.io"
ARG PATCHED_IMAGES_ORG="eclipse"
ARG PATCHED_IMAGES_TAG="nightly"
RUN TAG=${PATCHED_IMAGES_TAG} \
    ORGANIZATION=${PATCHED_IMAGES_ORG} \
    REGISTRY=${PATCHED_IMAGES_REG} \
    ./update_devfile_patched_image_tags.sh
RUN ./check_mandatory_fields.sh devfiles
RUN ./swap_images.sh devfiles
RUN if [[ ${USE_DIGESTS} == "true" ]]; then ./write_image_digests.sh devfiles; fi
RUN ./index.sh > /build/devfiles/index.json
RUN ./list_referenced_images.sh devfiles > /build/devfiles/external_images.txt
RUN chmod -R g+rwX /build/devfiles
CMD tail -f /dev/null

################# 
# PHASE TWO: configure registry image
################# 

# Build registry, copying meta.yamls and index.json from builder
# UPSTREAM: use RHEL7/RHSCL/httpd image so we're not required to authenticate with registry.redhat.io
# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/rhscl/httpd-24-rhel7
FROM registry.access.redhat.com/rhscl/httpd-24-rhel7:2.4-131 AS registry

# DOWNSTREAM: use RHEL8/httpd
# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/rhel8/httpd-24
# FROM registry.redhat.io/rhel8/httpd-24:1-118 AS registry
USER 0

# latest httpd container doesn't include ssl cert, so generate one
RUN chmod +x /usr/share/container-scripts/httpd/pre-init/40-ssl-certs.sh && \
    /usr/share/container-scripts/httpd/pre-init/40-ssl-certs.sh
RUN yum update -y gnutls systemd && yum clean all && rm -rf /var/cache/yum && \
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages"

# BEGIN these steps might not be required
RUN sed -i /etc/httpd/conf/httpd.conf \
    -e "s,Listen 80,Listen 8080," \
    -e "s,logs/error_log,/dev/stderr," \
    -e "s,logs/access_log,/dev/stdout," \
    -e "s,AllowOverride None,AllowOverride All," && \
    chmod a+rwX /etc/httpd/conf /run/httpd /etc/httpd/logs/
STOPSIGNAL SIGWINCH
# END these steps might not be required

WORKDIR /var/www/html

RUN mkdir -m 777 /var/www/html/devfiles
COPY .htaccess README.md /var/www/html/
COPY --from=builder /build/devfiles /var/www/html/devfiles
COPY ./images /var/www/html/images
COPY ./build/dockerfiles/rhel.entrypoint.sh ./build/dockerfiles/entrypoint.sh /usr/local/bin/
RUN chmod g+rwX /usr/local/bin/entrypoint.sh /usr/local/bin/rhel.entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/rhel.entrypoint.sh"]

# Offline registry build
FROM builder AS offline-builder
RUN ./cache_projects.sh devfiles resources && \
    ./cache_images.sh devfiles resources && \
    chmod -R g+rwX /build

FROM registry AS offline-registry
COPY --from=offline-builder /build/devfiles /var/www/html/devfiles
COPY --from=offline-builder /build/resources /var/www/html/resources

# append Brew metadata here
