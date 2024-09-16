#!/bin/bash -e
#
# Copyright (c) 2021-2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# this script will extract the filesystem of a container to a folder 
# so you can browse its contents. Also works with scratch images

DELETE_LOCAL_IMAGE=""
QUIET=""
TMPDIR="/tmp"

usage ()
{
  echo "Usage: $0 CONTAINER  

Examples:
  $0 quay.io/devspaces/devspaces-operator-bundle:latest
  $0 quay.io/devworkspace/devworkspace-operator-bundle:next
  $0 quay.io/devspaces/pluginregistry-rhel8:latest --tar-flags var/www/html/*/external_images.txt --arch ppc64le

Options:
  --delete-before  remove any local images before attempting to pull and extract a new copy
  --delete-after   remove any local images after attempting to pull and extract the container
  --arch           set a different arch than the current one, eg., s390x or ppc64le
  --tar-flags      pass flags to the tar extraction process
  --tmpdir         use a different folder for extraction than /tmp/
  -q, --quiet      quieter output
  "
  exit
}

if [[ $# -lt 1 ]]; then usage; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--delete-before') DELETE_LOCAL_IMAGE="${DELETE_LOCAL_IMAGE} before";;
    '--delete-after') DELETE_LOCAL_IMAGE="${DELETE_LOCAL_IMAGE} after";;
    '--override-arch'|'--arch') ARCH_OVERRIDE="--arch $2"; shift 1;;
    '--tar-flags'   ) TAR_FLAGS="$2"; shift 1;;
    '--tmpdir') TMPDIR="$2"; mkdir -p "$TMPDIR"; shift 1;;
    '-h') usage;;
    '-q'|'--quiet') QUIET="--quiet";;
    *) container="$1";;
  esac
  shift 1
done
# echo "ARCH_OVERRIDE = $ARCH_OVERRIDE"
# echo "TAR_FLAGS = $TAR_FLAGS"
# echo "container = $container"

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then
  if [[ $QUIET == "" ]]; then echo "[WARNING] podman is not installed."; fi
 PODMAN=$(command -v docker)
  if [[ ! -x $PODMAN ]]; then
    echo "[ERROR] docker is not installed. Aborting."; exit 1
  fi
fi

if [[ $container == *"@"* ]]; then
  tmpcontainer="$(echo "$container" | tr "/:@" "--")"
else 
  tmpcontainer="$(echo "$container" | tr "/:" "--")-$(date +%s)"
fi
unpackdir="$TMPDIR/${tmpcontainer}"

container_alt=""
for container_ref in "$container" "localhost/$container:latest" "localhost/$container"; do 
  if [[ $DELETE_LOCAL_IMAGE == *"before"* ]]; then
    # shellcheck disable=SC2086
    ${PODMAN} rmi $container_ref 2>/dev/null >/dev/null || true
  fi
  container_check="$(${PODMAN} images "$container_ref" -q)"
  if [[ $container_check ]]; then
    container_alt="$container_check"
    if [[ $QUIET == "" ]]; then echo "[INFO] Using local $container_ref ($container_alt)..."; fi
    break
  fi
done

# get remote image
if [[ ! $container_alt ]]; then
  # shellcheck disable=SC2086
  # CRW-3463 use --tls-verify=false to avoid "certificate signed by unknown authority"
  if [[ $QUIET == "" ]]; then 
    echo "[INFO] Pulling $container ..."
    ${PODMAN} pull ${QUIET} --tls-verify=false ${ARCH_OVERRIDE} "$container" 2>&1
  else
    ${PODMAN} pull ${QUIET} --tls-verify=false ${ARCH_OVERRIDE} "$container" 2>/dev/null 1>/dev/null
  fi
  # throw the same error code that a failed pull throws, in case we're running this in a nested bash shell
  ${PODMAN} image exists "$container" || exit 125
fi

# create local container
${PODMAN} rm -f "${tmpcontainer}"  >/dev/null 2>&1 || true
# use sh for regular containers or ls for scratch containers
if [[ $container_alt ]]; then 
  ${PODMAN} create --name="${tmpcontainer}" "$container_alt" sh >/dev/null  2>&1 || ${PODMAN} create --name="${tmpcontainer}" "$container_alt" ls >/dev/null 2>&1
else
  ${PODMAN} create --name="${tmpcontainer}" "$container" sh >/dev/null  2>&1 || ${PODMAN} create --name="${tmpcontainer}" "$container" ls >/dev/null 2>&1
fi

# export and unpack
${PODMAN} export "${tmpcontainer}" > "$TMPDIR/${tmpcontainer}.tar"
rm -fr "$unpackdir" || true
mkdir -p "$unpackdir"
# shellcheck disable=SC2086 disable=SC2116
TAR_FLAGS="$(echo $TAR_FLAGS)" # squash duplicate spaces
if [[ $QUIET == "" ]]; then echo "[INFO] Extract from container (${TAR_FLAGS}) ..."; fi
# shellcheck disable=SC2086
tar xf "$TMPDIR/${tmpcontainer}.tar" --wildcards -C "$unpackdir" ${TAR_FLAGS} || exit 1 # fail if we can't unpack the tar

# cleanup
${PODMAN} rm -f "${tmpcontainer}" >/dev/null 2>&1 || true
rm -fr "$TMPDIR/${tmpcontainer}.tar" || true

if [[ $QUIET == "" ]]; then 
  if [[ $container_alt ]]; then 
    echo "[INFO] Container $container ($container_alt) unpacked to $unpackdir"
  else
    echo "[INFO] Container $container unpacked to $unpackdir"
  fi
fi

if [[ $DELETE_LOCAL_IMAGE == *"after"* ]]; then
  # shellcheck disable=SC2086
  if [[ $container_alt ]]; then 
    ${PODMAN} rmi $container_alt 2>/dev/null >/dev/null || true
  else
    ${PODMAN} rmi $container 2>/dev/null >/dev/null || true
  fi
fi
