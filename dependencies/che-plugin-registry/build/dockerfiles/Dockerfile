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

# UBI Builder
# https://registry.access.redhat.com/ubi8/ubi
FROM registry.access.redhat.com/ubi8/ubi:8.6-903.1661794351 as ubi-builder

ARG BOOTSTRAP=false
ENV BOOTSTRAP=${BOOTSTRAP}

RUN mkdir -p /mnt/rootfs

RUN yum install --installroot /mnt/rootfs \
    java-11-openjdk coreutils-single glibc-minimal-langpack glibc-langpack-en langpacks-en glibc-locale-source httpd nc \
    net-tools procps vi curl wget tar gzip jq \
    --releasever 8 --nodocs -y && \
    yum --installroot /mnt/rootfs clean all && \
    rm -rf /mnt/rootfs/var/cache/* /mnt/rootfs/var/log/dnf* /mnt/rootfs/var/log/yum.*

# Add postgresql
COPY --chown=0:0 /postgresql13.tar.gz /
RUN tar -xf postgresql13.tar.gz && rm /postgresql13.tar.gz

# Use the final root filesystem as default directory
WORKDIR /mnt/rootfs

# Copy OpenVSX server files
COPY --chown=0:0 /openvsx-server.tar.gz .
RUN tar -xf openvsx-server.tar.gz && rm openvsx-server.tar.gz
# Copy our configuration file for OpenVSX server
COPY /build/dockerfiles/application.yaml /mnt/rootfs/openvsx-server/config/
RUN chmod -R g+rwx /mnt/rootfs/openvsx-server

# Copy NodeJS and OVSX files
RUN mkdir -p /mnt/rootfs/tmp/opt
COPY --chown=0:0 /nodejs.tar.gz .
RUN tar -xf nodejs.tar.gz -C /mnt/rootfs && rm nodejs.tar.gz

# Apply permissions to later change these files on httpd and postgres
RUN chmod g+rwx /mnt/rootfs/var/log/httpd && chmod g+rw /mnt/rootfs/run/httpd && chmod g+rw /mnt/rootfs/var/lib/pgsql

# Create user template
RUN cat /mnt/rootfs/etc/passwd | sed s#root:x.*#root:x:\${USER_ID}:\${GROUP_ID}::\${HOME}:/bin/bash#g > /mnt/rootfs/.passwd.template \
    && cat /mnt/rootfs/etc/group | sed s#root:x:0:#root:x:0:0,\${USER_ID}:#g > /mnt/rootfs/.group.template

# Change permissions
RUN for f in "/mnt/rootfs/etc/passwd" "/mnt/rootfs/etc/group" "/mnt/rootfs/var/lib/pgsql" "/mnt/rootfs/usr/pgsql-13" "/mnt/rootfs/var/run/postgresql"; do\
           chgrp -R 0 ${f} && \
           chmod -R g+rwX ${f}; \
       done

# Apply httpd config file
RUN sed -i /mnt/rootfs/etc/httpd/conf/httpd.conf \
    -e "s,Listen 80,Listen 8080," \
    -e "s,logs/error_log,/dev/stderr," \
    -e "s,logs/access_log,/dev/stdout," \
    -e "s,AllowOverride None,AllowOverride All," && \
    chmod a+rwX /mnt/rootfs/etc/httpd/conf /mnt/rootfs/etc/httpd/conf.d /mnt/rootfs/run/httpd /mnt/rootfs/etc/httpd/logs/

STOPSIGNAL SIGWINCH

RUN mkdir -m 777 /mnt/rootfs/var/www/html/v3
COPY /build/scripts/import_vsix.sh /mnt/rootfs/usr/local/bin
COPY /build/scripts/start_services.sh /mnt/rootfs/usr/local/bin/
RUN chmod 755 /mnt/rootfs/usr/local/bin/*.sh
COPY /build/dockerfiles/openvsx.conf /mnt/rootfs/etc/httpd/conf.d/

COPY README.md .htaccess /mnt/rootfs/var/www/html/

COPY /build/scripts/*.sh resources.tgz che-*.yaml /build/

RUN tar -xvf /build/resources.tgz -C /build/
RUN rm -rf /build/output/v3/che-theia-plugins.yaml /build/output/v3/che-editors.yaml /build/output/v3/che-plugins.yaml
RUN /build/swap_plugins_memory.sh /build/output/v3
RUN /build/list_referenced_images.sh /build/output/v3 --use-generated-content > /build/output/v3/external_images.txt && cat /build/output/v3/external_images.txt
RUN chmod -R g+rwX /build

RUN cp -r /build/output/v3 /mnt/rootfs/var/www/html/
COPY v3/plugins/ /mnt/rootfs/var/www/html/v3/plugins/
COPY v3/images/*.png /mnt/rootfs/var/www/html/v3/images/
COPY /build/dockerfiles/entrypoint.sh /mnt/rootfs/usr/local/bin/

# Apply permissions to later change these files (entrypoint update_extension_vsx_references)
RUN chmod g+rwx -R /mnt/rootfs/var/www/html/v3

# Use ubi8-minimal image and then copy ubi fs
FROM registry.access.redhat.com/ubi8/ubi-minimal:8.6-941
COPY --from=ubi-builder /mnt/rootfs/ /
# Add UTF-8 for the database
RUN localedef -f UTF-8 -i en_US en_US.UTF-8 && \
    useradd apache && \
    usermod -a -G apache,root,postgres postgres
USER postgres
ENV LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    PGDATA=/var/lib/pgsql/13/data/database \
    PATH="/tmp/opt/nodejs/bin:$PATH" \
    npm_config_cache=/tmp/opt/cache

ARG DS_BRANCH=devspaces-3-rhel-8
ENV DS_BRANCH=${DS_BRANCH}

RUN /usr/pgsql-13/bin/initdb && \
    # Add all vsix files to the database
    /usr/local/bin/import_vsix.sh && \
    # add permissions for anyuserid
    chgrp -R 0 /var/lib/pgsql/13/data/database && \
    #cleanup postgresql pid
    rm /var/lib/pgsql/13/data/database/postmaster.pid && \
    rm /var/run/postgresql/.s.PGSQL* && \
    rm /tmp/.s.PGSQL* && \
    chmod -R g+rwX /var/lib/pgsql/13/data/database && mv /var/lib/pgsql/13/data/database /var/lib/pgsql/13/data/old
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# append Brew metadata here
