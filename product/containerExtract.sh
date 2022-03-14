#!/bin/bash -e

DELETE_LOCAL_IMAGE=""

usage ()
{
  echo "Usage: $0 CONTAINER [--override-arch s390x] [--tar-flags tar-extraction-flags] [--delete-before] [--delete-after]"
  echo "Usage: $0 quay.io/devspaces/operator-bundle:latest"
  echo "Usage: $0 quay.io/devspaces/udi-rhel8:2.4"
  echo "Usage: $0 quay.io/devspaces/pluginregistry-rhel8:latest --tar-flags var/www/html/*/external_images.txt"
  echo "Usage: $0 quay.io/devspaces/devfileregistry-rhel8:latest --tar-flags var/www/html/*/external_images.txt --override-arch ppc64le"
  echo "
Options:
  --delete-before    remove any local images before attempting to pull and extract a new copy
  --delete-after     remove any local images after attempting to pull and extract the container"
  exit
}

if [[ $# -lt 1 ]]; then usage; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--override-arch') ARCH_OVERRIDE="--override-arch $2"; shift 1;;
    '--delete-after') DELETE_LOCAL_IMAGE="${DELETE_LOCAL_IMAGE} after";;
    '--delete-before') DELETE_LOCAL_IMAGE="${DELETE_LOCAL_IMAGE} before";;
    '--tar-flags'   ) TAR_FLAGS="$2"; shift 1;;
    '-h') usage;;
    *) container="$1";;
  esac
  shift 1
done
# echo "ARCH_OVERRIDE = $ARCH_OVERRIDE"
# echo "TAR_FLAGS = $TAR_FLAGS"
# echo "container = $container"

PODMAN=$(command -v podman)
if [[ ! -x $PODMAN ]]; then
  echo "[WARNING] podman is not installed."
 PODMAN=$(command -v docker)
  if [[ ! -x $PODMAN ]]; then
    echo "[ERROR] docker is not installed. Aborting."; exit 1
  fi
fi

if [[ ${ARCH_OVERRIDE} == "" ]] && [[ ${container} == *"-openj9"* ]]; then
  ARCH_OVERRIDE="--override-arch s390x"
fi

if [[ $container == *"@"* ]]; then
  tmpcontainer="$(echo "$container" | tr "/:@" "--")"
else 
  tmpcontainer="$(echo "$container" | tr "/:" "--")-$(date +%s)"
fi
unpackdir="/tmp/${tmpcontainer}"

container_alt=""
for container_ref in "$container" "localhost/$container:latest" "localhost/$container"; do 
  if [[ $DELETE_LOCAL_IMAGE == *"before"* ]]; then
    ${PODMAN} rmi $container_ref 2>/dev/null >/dev/null || true
  fi
  container_check="$(${PODMAN} images "$container_ref" -q)"
  if [[ $container_check ]]; then
    container_alt="$container_check"
    echo "[INFO] Using local $container_ref ($container_alt)..."
    break
  fi
done
if [[ ! $container_alt ]]; then
  # get remote image
  echo "[INFO] Pulling $container ..."
  # shellcheck disable=SC2086
  ${PODMAN} pull ${ARCH_OVERRIDE} "$container" 2>&1
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
${PODMAN} export "${tmpcontainer}" > "/tmp/${tmpcontainer}.tar"
rm -fr "$unpackdir" || true
mkdir -p "$unpackdir"
# shellcheck disable=SC2086 disable=SC2116
TAR_FLAGS="$(echo $TAR_FLAGS)" # squash duplicate spaces
echo "[INFO] Extract from container (${TAR_FLAGS}) ..."
# shellcheck disable=SC2086
tar xf "/tmp/${tmpcontainer}.tar" --wildcards -C "$unpackdir" ${TAR_FLAGS} || exit 1 # fail if we can't unpack the tar

# cleanup
${PODMAN} rm -f "${tmpcontainer}" >/dev/null 2>&1 || true
rm -fr "/tmp/${tmpcontainer}.tar" || true

if [[ $container_alt ]]; then 
  echo "[INFO] Container $container ($container_alt) unpacked to $unpackdir"
else
  echo "[INFO] Container $container unpacked to $unpackdir"
fi

if [[ $DELETE_LOCAL_IMAGE == *"after"* ]]; then
  if [[ $container_alt ]]; then 
    ${PODMAN} rmi $container_alt || true
  else
    ${PODMAN} rmi $container || true
  fi
fi
