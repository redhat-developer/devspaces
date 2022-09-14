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

# open-vsx builder
FROM registry.access.redhat.com/ubi8/openjdk-11:1.14-3.1661798377 as openvsx-builder
USER 0

RUN microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y git

# It uses gradlew that downloads gradle to build sources
COPY ./build/scripts/build_openvsx.sh /tmp
RUN /tmp/build_openvsx.sh && rm /tmp/build_openvsx.sh

# Builder: check meta.yamls and create index.json
# https://registry.access.redhat.com/ubi8/python-38
FROM registry.access.redhat.com/ubi8/python-38:1-100 as builder
USER 0

ARG BOOTSTRAP=false
ENV BOOTSTRAP=${BOOTSTRAP}

# to get all the python deps pre-fetched so we can build in Brew:
# 1. extract files in the container to your local filesystem
#    find v3 -type f -exec dos2unix {} \;

# NOTE: used to be in /root/.local but now can be found in /opt/app-root/src/.local
# CONTAINERNAME=pluginregistryoffline && \
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

COPY ./build/scripts/*.sh /build/
COPY che-*.yaml /build/
COPY resources.tgz /build/
COPY ./v3/plugins/ /build/v3/plugins/
COPY ./v3/images/*.png /build/v3/images/
WORKDIR /build/

RUN tar -xvf resources.tgz -C ./
RUN rm -rf ./output/v3/che-theia-plugins.yaml ./output/v3/che-editors.yaml ./output/v3/che-plugins.yaml
RUN ./swap_plugins_memory.sh ./output/v3
RUN ./list_referenced_images.sh ./output/v3 --use-generated-content > /build/output/v3/external_images.txt && cat /build/output/v3/external_images.txt
RUN chmod -R g+rwX /build

# Build registry, copying meta.yamls and index.json from builder
# https://registry.access.redhat.com/ubi8/httpd-24
FROM registry.access.redhat.com/ubi8/httpd-24:1-199 AS registry
USER 0

# Install postgresql and jdk
RUN yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
RUN yum install postgresql14-libs postgresql14 postgresql14-server java-11-openjdk jq\
    --releasever 8 --nodocs -y
RUN chmod g+rw /var/lib/pgsql

# change permissions for pgsql
RUN for f in "/etc/passwd" "/etc/group" "/var/lib/pgsql" "/usr/pgsql-14" "/var/run/postgresql"; do\
           chgrp -R 0 ${f} && \
           chmod -R g+rwX ${f}; \
    done

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
    -e "s,logs/access_log,/dev/stdout," \
    -e "s,AllowOverride None,AllowOverride All," && \
    chmod a+rwX /etc/httpd/conf /etc/httpd/conf.d /run/httpd /var/log/httpd /etc/httpd/logs/
STOPSIGNAL SIGWINCH

ARG DS_BRANCH=devspaces-3-rhel-8

# Add UTF-8 for the database
RUN localedef -f UTF-8 -i en_US en_US.UTF-8 && \
    usermod -a -G apache,root,postgres postgres

ENV DS_BRANCH=${DS_BRANCH} \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    PGDATA=/var/lib/pgsql/14/data/database

RUN mkdir -m 777 /openvsx-server
# Copy OpenVSX server files
COPY --from=openvsx-builder /tmp/openvsx-lib/ /openvsx-server
# Copy OpenVSX configuration files
COPY ./build/dockerfiles/application.yaml /openvsx-server/config/
COPY ./build/dockerfiles/openvsx.conf /etc/httpd/conf.d/
COPY ./build/dockerfiles/openvsx-sync.json /openvsx-server/
COPY ./build/dockerfiles/start-services.sh /usr/local/bin/
COPY ./build/dockerfiles/import-vsix.sh /usr/local/bin/

WORKDIR /var/www/html

RUN mkdir -m 777 /var/www/html/v3
COPY README.md .htaccess /var/www/html/
COPY --from=builder /build/output/v3 /var/www/html/v3
COPY --from=builder /build/v3/plugins/ /var/www/html/v3/plugins/
COPY --from=builder /build/v3/images/ /var/www/html/v3/images/
COPY ./build/dockerfiles/rhel.entrypoint.sh ./build/dockerfiles/entrypoint.sh /usr/local/bin/

RUN chmod g+rwX /usr/local/bin/entrypoint.sh /usr/local/bin/rhel.entrypoint.sh && \
    chgrp -R 0 /var/www/html && chmod -R g+rw /var/www/html

USER postgres

RUN /usr/pgsql-14/bin/initdb && \
    chmod -R g+rwX /var/run/postgresql && \
    chgrp -R 0 /var/run/postgresql && \
    # Add all vsix files to the database
    /usr/local/bin/import-vsix.sh && \
    # add permissions for anyuserid
    chgrp -R 0 /var/lib/pgsql/14/data/database && \
    #cleanup postgresql pid
    rm /var/lib/pgsql/14/data/database/postmaster.pid && \
    rm /var/run/postgresql/.s.PGSQL* && \
    rm /tmp/.s.PGSQL* && \
    chmod -R g+rwX /var/lib/pgsql/14/data/database && mv /var/lib/pgsql/14/data/database /var/lib/pgsql/14/data/old

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/rhel.entrypoint.sh"]

# append Brew metadata here
