#!/bin/bash -x

# start httpd
if [[ -x /usr/sbin/httpd ]]; then /usr/sbin/httpd -D FOREGROUND
elif [[ -x /usr/bin/run-httpd ]]; then /usr/bin/run-httpd
fi
