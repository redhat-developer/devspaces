#!/bin/bash
#
# Copyright (c) 2012-2018 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    echo "${USER_NAME:-jboss}:x:$(id -u):0:${USER_NAME:-jboss} user:${HOME}:/sbin/nologin" >> /etc/passwd
  fi
fi

set -x

# start httpd
if [[ -x /usr/sbin/httpd ]]; then
  /usr/sbin/httpd -D FOREGROUND
elif [[ -x /usr/bin/run-httpd ]]; then
  /usr/bin/run-httpd
fi
