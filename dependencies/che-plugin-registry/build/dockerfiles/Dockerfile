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
FROM docker.io/alpine:3.11.5 AS builder
RUN apk add --no-cache py-pip jq bash wget skopeo && pip install yq jsonschema

ARG LATEST_ONLY=false
ARG USE_DIGESTS=false

COPY ./build/scripts/*.sh ./build/scripts/meta.yaml.schema /build/
COPY /v3 /build/v3
WORKDIR /build/

RUN if [[ ${LATEST_ONLY} == "true" ]]; then \
      ./keep_only_latest.sh; \
    fi
RUN ./generate_latest_metas.sh v3
RUN ./check_plugins_location.sh v3
RUN ./set_plugin_dates.sh v3
RUN ./check_metas_schema.sh v3
RUN if [[ ${USE_DIGESTS} == "true" ]]; then ./write_image_digests.sh v3;fi
RUN ./index.sh v3 > /build/v3/plugins/index.json
RUN ./list_referenced_images.sh v3 > /build/v3/external_images.txt
RUN chmod -R g+rwX /build

# Build registry, copying meta.yamls and index.json from builder
FROM docker.io/httpd:2.4.43-alpine AS registry
# Allow htaccess
RUN sed -i 's|    AllowOverride None|    AllowOverride All|' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's|Listen 80|Listen 8080|' /usr/local/apache2/conf/httpd.conf && \
    mkdir -p /var/www && ln -s /usr/local/apache2/htdocs /var/www/html && \
    chmod -R g+rwX /usr/local/apache2 && \
    echo "ServerName localhost" >> /usr/local/apache2/conf/httpd.conf
COPY README.md .htaccess /usr/local/apache2/htdocs/
COPY --from=builder /build/v3 /usr/local/apache2/htdocs/v3
COPY ./build/dockerfiles/entrypoint.sh /usr/bin/
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["httpd-foreground"]

# Offline build: cache .theia and .vsix files in registry itself and update metas
FROM builder AS offline-builder
RUN ./cache_artifacts.sh v3 && chmod -R g+rwX /build

# Offline registry: copy updated meta.yamls and cached extensions
FROM registry AS offline-registry
COPY --from=offline-builder /build/v3 /usr/local/apache2/htdocs/v3
