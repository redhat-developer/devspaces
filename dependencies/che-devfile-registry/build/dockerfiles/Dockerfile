#
# Copyright (c) 2018-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
FROM docker.io/alpine:3.11.5 AS builder
RUN apk add --no-cache py-pip jq bash wget git skopeo && pip install yq

# Registry, organization, and tag to use for base images in dockerfiles. Devfiles
# will be rewritten during build to use these values for base images.
ARG PATCHED_IMAGES_REG="quay.io"
ARG PATCHED_IMAGES_ORG="eclipse"
ARG PATCHED_IMAGES_TAG="nightly"
ARG USE_DIGESTS=false

COPY ./build/scripts ./arbitrary-users-patch/base_images /build/
COPY ./devfiles /build/devfiles
WORKDIR /build/
RUN TAG=${PATCHED_IMAGES_TAG} \
    ORGANIZATION=${PATCHED_IMAGES_ORG} \
    REGISTRY=${PATCHED_IMAGES_REG} \
    ./update_devfile_patched_image_tags.sh
RUN ./check_mandatory_fields.sh devfiles
RUN if [[ ${USE_DIGESTS} == "true" ]]; then ./write_image_digests.sh devfiles; fi
RUN ./index.sh > /build/devfiles/index.json
RUN ./list_referenced_images.sh devfiles > /build/devfiles/external_images.txt
RUN chmod -R g+rwX /build/devfiles

FROM docker.io/httpd:2.4.43-alpine AS registry
# Allow htaccess
RUN sed -i 's|    AllowOverride None|    AllowOverride All|' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's|Listen 80|Listen 8080|' /usr/local/apache2/conf/httpd.conf && \
    mkdir -m 777 /usr/local/apache2/htdocs/devfiles && \
    mkdir -p /var/www && ln -s /usr/local/apache2/htdocs /var/www/html && \
    chmod -R g+rwX /usr/local/apache2 && \
    echo "ServerName localhost" >> /usr/local/apache2/conf/httpd.conf
COPY .htaccess README.md /usr/local/apache2/htdocs/
COPY --from=builder /build/devfiles /usr/local/apache2/htdocs/devfiles
COPY ./images /usr/local/apache2/htdocs/images
COPY ./build/dockerfiles/entrypoint.sh /usr/bin/
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["httpd-foreground"]


# Offline registry: download project zips and place them in /build/resources
FROM builder AS offline-builder
RUN ./cache_projects.sh devfiles resources && \
    ./cache_images.sh devfiles resources && \
    chmod -R g+rwX /build

# Offline registry: copy updated devfile.yamls and cached projects
FROM registry AS offline-registry
COPY --from=offline-builder /build/devfiles /usr/local/apache2/htdocs/devfiles
COPY --from=offline-builder /build/resources /usr/local/apache2/htdocs/resources
