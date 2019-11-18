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
FROM registry.access.redhat.com/ubi8-minimal:8.1-279 as builder
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
#    CONTAINERNAME="pluginregistrybuilder" && docker build -t ${CONTAINERNAME} . --target=builder --no-cache --squash --build-arg BOOTSTRAP=true
#    mkdir -p /tmp/root-local/ && docker run -it -v /tmp/root-local/:/tmp/root-local/ ${CONTAINERNAME} /bin/bash -c "cd /root/.local/ && cp -r bin/ lib/ /tmp/root-local/"
#    pushd /tmp/root-local >/dev/null && sudo tar czf root-local.tgz lib/ bin/ && popd >/dev/null && mv -f /tmp/root-local/root-local.tgz . && sudo rm -fr /tmp/root-local/

# 2. then add it to dist-git so it's part of this repo
#    rhpkg new-sources root-local.tgz 

# built in Brew, use tarball in lookaside cache; built locally, comment this out
# COPY root-local.tgz /tmp/root-local.tgz

# NOTE: uncomment for local build. Must also set full registry path in FROM to registry.redhat.io or registry.access.redhat.com
# enable rhel 7 or 8 content sets (from Brew) to resolve jq as rpm
COPY ./build/dockerfiles/content_sets_epel7.repo /etc/yum.repos.d/

COPY ./build/dockerfiles/rhel.install.sh /tmp
RUN /tmp/rhel.install.sh && rm -f /tmp/rhel.install.sh

################# 
# PHASE TWO: configure registry image
#################

COPY ./build/scripts/*.sh ./build/scripts/meta.yaml.schema /build/
COPY /v3 /build/v3
WORKDIR /build/

# if only including the /latest/ plugins, apply this line to remove them from builder
RUN if [[ ${LATEST_ONLY} == "true" ]]; then \
      ./keep_only_latest.sh; \
    fi

RUN ./generate_latest_metas.sh v3 && \
    ./check_plugins_location.sh v3 && \
    ./set_plugin_dates.sh v3 && \
    ./check_plugins_viewer_mandatory_fields.sh v3 && \
    ./index.sh v3 > /build/v3/plugins/index.json && \
    ./list_referenced_images.sh v3 > /build/v3/external_images.txt && \
    chmod -R g+rwX /build

################# 
# PHASE THREE: create ubi8-minimal image with httpd
################# 

# Build registry, copying meta.yamls and index.json from builder
# UPSTREAM: use RHEL7/RHSCL/httpd image so we're not required to authenticate with registry.redhat.io
# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/rhscl/httpd-24-rhel7
# FROM registry.access.redhat.com/rhscl/httpd-24-rhel7:2.4-105 AS registry

# DOWNSTREAM: use RHEL8/httpd
# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/rhel8/httpd-24
FROM registry.redhat.io/rhel8/httpd-24:1-63 AS registry
USER 0

# BEGIN these steps might not be required
RUN sed -i /etc/httpd/conf/httpd.conf \
    -e "s,Listen 80,Listen 8080," \
    -e "s,logs/error_log,/dev/stderr," \
    -e "s,logs/access_log,/dev/stdout," \
    -e "s,AllowOverride None,AllowOverride All," && \
    chmod a+rwX /etc/httpd/conf /run/httpd /etc/httpd/logs/
STOPSIGNAL SIGWINCH
# END these steps might not be required

COPY README.md .htaccess /var/www/html/
COPY --from=builder /build/v3 /var/www/html/v3
COPY ./build/dockerfiles/rhel.entrypoint.sh ./build/dockerfiles/entrypoint.sh /usr/local/bin/

WORKDIR /var/www/html
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/rhel.entrypoint.sh"]

# Offline build: cache .theia and .vsix files in registry itself and update metas
# multiple temp stages does not work in Brew
FROM builder AS offline-builder

# built in Brew, use tarball in lookaside cache; built locally, comment this out
# COPY v3.tgz /tmp/v3.tgz

# to get all the cached vsix files pre-fetched so we can use them in Brew:
# 1. extract files in the container to your local filesystem
#    CONTAINERNAME="pluginregistryoffline" && docker build -t ${CONTAINERNAME} . --target=offline-builder --no-cache --squash --build-arg BOOTSTRAP=true
#    mkdir -p /tmp/pr-res/ && docker run -it -v /tmp/pr-res/:/tmp/pr-res/ ${CONTAINERNAME} /bin/bash -c "cd /build/v3/ && cp -r ./* /tmp/pr-res/"
#    pushd /tmp/pr-res >/dev/null && sudo tar czf v3.tgz ./* && popd >/dev/null && mv -f /tmp/pr-res/v3.tgz . && sudo rm -fr /tmp/pr-res/

# 2. then add it to dist-git so it's part of this repo
#    rhpkg new-sources root-local.tgz v3.tgz
RUN if [ ! -f /tmp/v3.tgz ] || [ ${BOOTSTRAP} == "true" ]; then \
      ./cache_artifacts.sh v3 && chmod -R g+rwX /build; \
    else \
      # in Brew use /var/www/html/; in upstream/ offline-builder use /build/
      mkdir -p /build/v3/; tar xf /tmp/v3.tgz -C /build/v3/; rm -fr /tmp/v3.tgz; chmod -R g+rwX /build/v3/; \
    fi

# multiple temp stages does not work in Brew
FROM registry AS offline-registry
USER 0

# multiple temp stages does not work in Brew
COPY --from=offline-builder /build/v3 /var/www/html/v3

ENV SUMMARY="Red Hat CodeReady Workspaces plugin registry container" \
    DESCRIPTION="Red Hat CodeReady Workspaces plugin registry container" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="pluginregistry-rhel8"

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
