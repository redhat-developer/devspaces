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
FROM alpine:3.10 AS builder
RUN apk add --no-cache py-pip jq bash wget && pip install yq jsonschema

ARG LATEST_ONLY=false

COPY ./build/scripts/*.sh ./build/scripts/meta.yaml.schema /build/
COPY /v3 /build/v3
WORKDIR /build/

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

# Build registry, copying meta.yamls and index.json from builder
FROM registry.centos.org/centos/httpd-24-centos7 AS registry
COPY README.md .htaccess /var/www/html/
COPY --from=builder /build/v3 /var/www/html/v3
COPY ./build/dockerfiles/entrypoint.sh /usr/bin/
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["/usr/bin/run-httpd"]

# Offline build: cache .theia and .vsix files in registry itself and update metas
FROM builder AS offline-builder
RUN ./cache_artifacts.sh v3 && chmod -R g+rwX /build

# Offline registry: copy updated meta.yamls and cached extensions
FROM registry AS offline-registry
COPY --from=offline-builder /build/v3 /var/www/html/v3
