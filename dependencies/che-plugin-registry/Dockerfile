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
# to get all the python deps pre-fetched so we can build in Brew:
# 1. extract files in the container to your local filesystem
#    CONTAINERNAME="pluginregistrybuilder" && docker build -t ${CONTAINERNAME} . --target=builder --no-cache --squash --build-arg BOOTSTRAP=true
#    mkdir -p /tmp/root-local/ && docker run -it -v /tmp/root-local/:/tmp/root-local/ ${CONTAINERNAME} /bin/bash -c "cd /root/.local/ && cp -r bin/ lib/ /tmp/root-local/"
#    pushd /tmp/root-local >/dev/null && sudo tar czf root-local.tgz lib/ bin/ && popd >/dev/null && mv -f /tmp/root-local/root-local.tgz . && sudo rm -fr /tmp/root-local/

# 2. then add it to dist-git so it's part of this repo
#    rhpkg new-sources root-local.tgz 

# built in Brew, use tarball in lookaside cache; built locally, comment this out
# COPY root-local.tgz /tmp/root-local.tgz

# NOTE: uncomment for local build. Must also set full registry path in FROM to registry.redhat.io or registry.access.redhat.com
# enable rhel 7 or 8 content sets (from Brew) to resolve jq as rpm
COPY content_sets_epel7.repo /etc/yum.repos.d/

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

################# 
# PHASE TWO: configure registry image
#################

COPY ./scripts/*.sh ./scripts/meta.yaml.schema /build/
COPY /v3 /build/v3
WORKDIR /build/

# if only including the /latest/ plugins, apply this line to remove them from builder 
RUN rm -fr $(find /build/v3 -name 'meta.yaml' | grep -v "/latest/")

# not supported in Brew unless we prefetch the content via tarball injection
# optional steps for air gap - replace references to docker.io, quay.io, registry.access.redhat.com, registry.redhat.io with internal registry
# RUN ./list_containers.sh v3 && ./replace_container_repos.sh v3 myquay.mycorp.com

RUN ./check_plugins_location.sh v3 && \
    ./set_plugin_dates.sh v3 && \
    ./check_plugins_viewer_mandatory_fields.sh v3 && \
    ./ensure_latest_exists.sh && \
    ./index.sh v3 > /build/v3/plugins/index.json && \
    chmod -c -R g+rwX /build

################# 
# PHASE THREE: create ubi8-minimal image with httpd
################# 

# Build registry, copying meta.yamls and index.json from builder
# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/rhscl/httpd-24-rhel7
FROM registry.access.redhat.com/rhscl/httpd-24-rhel7:2.4-104 AS registry
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

COPY README.md .htaccess /var/www/html/
COPY --from=builder /build/v3 /var/www/html/v3
COPY ./scripts/*entrypoint.sh /usr/local/bin/

WORKDIR /var/www/html
ENTRYPOINT ["/usr/local/bin/uid_entrypoint.sh", "/usr/local/bin/entrypoint.sh"]

# Offline build: cache .theia and .vsix files in registry itself and update metas
# multiple temp stages does not work in Brew
FROM builder AS offline-builder

# built in Brew, use tarball in lookaside cache; built locally, comment this out
# COPY resources.tgz /tmp/resources.tgz

# to get all the python deps pre-fetched so we can build in Brew:
# 1. extract files in the container to your local filesystem
#    CONTAINERNAME="pluginregistryoffline" && docker build -t ${CONTAINERNAME} . --target=offline-builder --no-cache --squash --build-arg BOOTSTRAP=true
#    mkdir -p /tmp/pr-res/ && docker run -it -v /tmp/pr-res/:/tmp/pr-res/ ${CONTAINERNAME} /bin/bash -c "cd /build/v3/resources/ && cp -r ./* /tmp/pr-res/"
#    pushd /tmp/pr-res >/dev/null && sudo tar czf resources.tgz ./* && popd >/dev/null && mv -f /tmp/pr-res/resources.tgz . && sudo rm -fr /tmp/pr-res/

# 2. then add it to dist-git so it's part of this repo
#    rhpkg new-sources root-local.tgz resources.tgz

RUN if [[ ! -f /tmp/resources.tgz ]] || [[ ${BOOTSTRAP} == "true" ]]; then \
      # To only cache files from /latest/ folders, use ./cache_artifacts.sh v3 --latest-only 
      # and uncomment line above to remove files so they're not included in index.json -- RUN rm -fr $(find /build/v3 -name 'meta.yaml' | grep -v "/latest/")
      ./cache_artifacts.sh v3 --latest-only && chmod -R g+rwX /build; \
    else \
      mkdir -p /build/v3/resources/; tar xf /tmp/resources.tgz -C /build/v3/resources/; rm -fr /tmp/resources.tgz;  \
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
