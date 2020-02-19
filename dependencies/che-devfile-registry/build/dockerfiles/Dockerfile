#
# Copyright (c) 2018-2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
FROM alpine:3.10 AS builder
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

FROM registry.centos.org/centos/httpd-24-centos7 AS registry
RUN mkdir -m 777 /var/www/html/devfiles
COPY .htaccess README.md /var/www/html/
COPY --from=builder /build/devfiles /var/www/html/devfiles
COPY ./images /var/www/html/images
COPY ./build/dockerfiles/entrypoint.sh /usr/bin/
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["/usr/bin/run-httpd"]


# Offline registry: download project zips and place them in /build/resources
FROM builder AS offline-builder
RUN ./cache_projects.sh devfiles resources && \
    ./cache_images.sh devfiles resources && \
    chmod -R g+rwX /build

# Offline registry: copy updated devfile.yamls and cached projects
FROM registry AS offline-registry
COPY --from=offline-builder /build/devfiles /var/www/html/devfiles
COPY --from=offline-builder /build/resources /var/www/html/resources
