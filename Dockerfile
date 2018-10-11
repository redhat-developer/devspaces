# Copyright (c) 2012-2018 Red Hat, Inc.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

FROM registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift
COPY entrypoint.sh /entrypoint.sh
ADD assembly/assembly-main/target/codeready-6.12.1/codeready-6.12.1 /home/jboss/codeready
USER root
RUN mkdir -p /logs /data && \
    for f in "/home/jboss" "/data" "/logs"; do\
        chgrp -R 0 ${f} && \
        chmod -R g+rwX ${f}; \
    done
USER jboss
ENTRYPOINT ["/entrypoint.sh"]
