#!/bin/bash
#
# Copyright (c) 2018-2024 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

set -e

function run_main() {
    # Add current (arbitrary) user to /etc/passwd and /etc/group
    if ! whoami &> /dev/null; then
        if [ -w /etc/passwd ]; then
            echo "${USER_NAME:-postgres}:x:$(id -u):0:${USER_NAME:-postgres} user:${HOME}:/sbin/nologin" >> /etc/passwd
        fi
    fi

    # Check if START_OPENVSX has been defined
    # if not, default to false
    START_OPENVSX=${START_OPENVSX:-false}
    
    # start only if wanted
    if [ "${START_OPENVSX}" == "true" ]; then
      # change permissions
      cp -r /var/lib/pgsql/15/data/old /var/lib/pgsql/15/data/database
      rm -rf /var/lib/pgsql/15/data/old

      # start postgres and openvsx
      /usr/local/bin/start_services.sh
    fi

    # start httpd
    if [[ -x /usr/sbin/httpd ]]; then
      /usr/sbin/httpd -D FOREGROUND
    elif [[ -x /usr/bin/run-httpd ]]; then
      /usr/bin/run-httpd
    fi
}

# do not execute the main function in unit tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
    run_main "${@}"
fi
