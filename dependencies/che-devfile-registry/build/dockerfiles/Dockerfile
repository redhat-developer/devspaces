#
# Copyright (c) 2018-2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#   IBM Corporation - implementation
#

# Builder: check meta.yamls and create index.json
# https://registry.access.redhat.com/ubi8/python-311
FROM registry.access.redhat.com/ubi8/python-311:1-18.1692783648 as builder
USER 0

################# 
# PHASE ONE: create ubi8 image with yq
################# 

ARG BOOTSTRAP=false
ENV BOOTSTRAP=${BOOTSTRAP}
# if not defined or string is null, allow all registries/tags in list_referenced_images
# otherwise restrict to only those space-separated registries/tags; if others found, build will fail
# useful for failing build if quay images in an RC, or wrong devspaces image tag (3.2 in 3.1 build)
ARG ALLOWED_REGISTRIES=""
ENV ALLOWED_REGISTRIES=${ALLOWED_REGISTRIES}
ARG ALLOWED_TAGS=""
ENV ALLOWED_TAGS=${ALLOWED_TAGS}

# to get all the python deps pre-fetched so we can build in Brew:
# 1. extract files in the container to your local filesystem
#    find v3 -type f -exec dos2unix {} \;

# NOTE: used to be in /root/.local but now can be found in /opt/app-root/src/.local
# CONTAINERNAME=devfileregistryoffline && \
# docker build -t ${CONTAINERNAME} . --no-cache  --target builder \
#   --build-arg BOOTSTRAP=true -f build/dockerfiles/Dockerfile 
# mkdir -p /tmp/root-local/ && docker run --rm -v \
#   /tmp/root-local/:/tmp/root-local/ ${CONTAINERNAME} /bin/bash \
#   -c 'cd /opt/app-root/src/.local/ && cp -r bin/ lib/ /tmp/root-local/'
# pushd /tmp/root-local >/dev/null && sudo tar czf root-local.tgz lib/ bin/ && popd >/dev/null && mv -f /tmp/root-local/root-local.tgz . && sudo rm -fr /tmp/root-local/

# 2. then add it to dist-git so it's part of this repo
#    rhpkg new-sources root-local.tgz 

# built in Brew, use tarball in lookaside cache; built locally, comment this out
# COPY root-local.tgz /tmp/root-local.tgz

# NOTE: uncomment for local build. Must also set full registry path in FROM to registry.redhat.io or registry.access.redhat.com
# enable rhel 7 or 8 content sets (from Brew) to resolve jq as rpm
COPY ./build/dockerfiles/content_set*.repo /etc/yum.repos.d/
COPY ./build/dockerfiles/rhel.install.sh /tmp
RUN /tmp/rhel.install.sh && rm -f /tmp/rhel.install.sh

COPY ./build/scripts /build/
COPY ./devfiles /build/devfiles
COPY ./resources /build/resources
WORKDIR /build/

# Registry, organization, and tag to use for base images in dockerfiles. Devfiles
# will be rewritten during build to use these values for base images.
ARG PATCHED_IMAGES_REG="quay.io"
ARG PATCHED_IMAGES_ORG="eclipse"
ARG PATCHED_IMAGES_TAG="next"

# validate devfile content
RUN ./check_referenced_images.sh devfiles --registries "${ALLOWED_REGISTRIES}" --tags "${ALLOWED_TAGS}"
RUN ./check_mandatory_fields.sh devfiles

# Cache projects in DS 
RUN ./index.sh > /build/devfiles/index.json && cp /build/devfiles/index.json /build/index && \
    ./list_referenced_images.sh devfiles > /build/devfiles/external_images.txt && \
    ./list_referenced_images_by_file.sh devfiles > /build/devfiles/external_images_by_devfile.txt && \
    chmod -R g+rwX /build/devfiles /build/resources

################# 
# PHASE TWO: configure registry image
################# 

# Build registry, copying meta.yamls and index.json from builder
# https://registry.access.redhat.com/ubi8/httpd-24
FROM registry.access.redhat.com/ubi8/httpd-24:1-274.1692780861 AS registry
USER 0

# latest httpd container doesn't include ssl cert, so generate one
RUN chmod +x /usr/share/container-scripts/httpd/pre-init/40-ssl-certs.sh && \
    /usr/share/container-scripts/httpd/pre-init/40-ssl-certs.sh
RUN \
    yum -y -q update && \
    yum -y -q clean all && rm -rf /var/cache/yum && \
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages"

RUN echo "<FilesMatch "\""^\\.ht"\"">" >> /etc/httpd/conf/httpd.conf && \
    echo "Require all denied" >> /etc/httpd/conf/httpd.conf && \
    echo "</FilesMatch>" >> /etc/httpd/conf/httpd.conf

RUN sed -i /etc/httpd/conf.d/ssl.conf \
    -e "s,SSLProtocol all -SSLv2,SSLProtocol all -SSLv3," \
    -e "s,SSLCipherSuite HIGH:MEDIUM:!aNULL:!MD5,SSLCipherSuite HIGH:!aNULL:!MD5,"

RUN sed -i /etc/httpd/conf/httpd.conf \
    -e "s,Listen 80,Listen 8080," \
    -e "s,logs/error_log,/dev/stderr," \
    -e "/<IfModule log_config_module>/a SetEnvIf User-Agent \"^kube-probe/\" dontlog" \
    -e 's,CustomLog "logs/access_log" combined,CustomLog /dev/stdout combined env=!dontlog,' \
    -e "s,AllowOverride None,AllowOverride All," && \
    chmod a+rwX /etc/httpd/conf /run/httpd /etc/httpd/logs/
STOPSIGNAL SIGWINCH

ARG DS_BRANCH=devspaces-3-rhel-8
ENV DS_BRANCH=${DS_BRANCH}

WORKDIR /var/www/html

RUN mkdir -m 777 /var/www/html/devfiles
COPY README.md .htaccess /var/www/html/
COPY --from=builder /build/devfiles /var/www/html/devfiles
COPY --from=builder /build/resources /var/www/html/resources
COPY --from=builder /build/devfiles/index.json /var/www/html/index
COPY ./images /var/www/html/images
COPY ./build/dockerfiles/rhel.entrypoint.sh ./build/dockerfiles/entrypoint.sh /usr/local/bin/
RUN chmod g+rwX /usr/local/bin/entrypoint.sh /usr/local/bin/rhel.entrypoint.sh && \
    chgrp -R 0 /var/www/html && chmod -R g+rw /var/www/html
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/rhel.entrypoint.sh"]

# Offline build
FROM builder AS offline-builder
RUN ./cache_projects.sh devfiles resources && \
    ./cache_images.sh devfiles resources && \
    chmod -R g+rwX /build

FROM registry AS offline-registry
COPY --from=offline-builder /build/devfiles /var/www/html/devfiles
COPY --from=offline-builder /build/devfiles/index.json /var/www/html/index
COPY --from=offline-builder /build/resources /var/www/html/resources

# append Brew metadata here
