#!/bin/sh
if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    echo "${USER_NAME:-jboss}:x:$(id -u):0:${USER_NAME:-jboss} user:${HOME}:/sbin/nologin" >> /etc/passwd
  fi
fi
exec "$@"