#!/bin/bash
set -e +x

usage ()
{
  echo "Usage: $0 CONTAINER [--override-arch s390x] [--tar-flags tar-extraction-flags]"
  echo "Usage: $0 quay.io/crw/operator-metadata:latest"
  echo "Usage: $0 quay.io/crw/plugin-java8-openj9-rhel8:2.4 --override-arch s390x"
  echo "Usage: $0 quay.io/crw/pluginregistry-rhel8:latest --tar-flags var/www/html/*/external_images.txt"
  echo "Usage: $0 quay.io/crw/devfileregistry-rhel8:latest --tar-flags var/www/html/*/external_images.txt --override-arch ppc64le"
  exit
}

if [[ $# -lt 1 ]]; then usage; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--override-arch') ARCH_OVERRIDE="--override-arch $2"; shift 1;;
    '--tar-flags'   ) TAR_FLAGS="$2"; shift 1;;
    '-h') usage; shift 0;;
    *) container="$1"; shift 0;;
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

tmpcontainer="$(echo $container | tr "/:" "--")-$(date +%s)"
unpackdir="/tmp/${tmpcontainer}"

if [[ $(${PODMAN} images | grep $container) ]] || [[ $(${PODMAN} images localhost/$container:latest -q) ]] || [[ $(${PODMAN} images localhost/$container -q) ]]; then
  echo "[INFO] Using local $container ..."
else
  # get remote image
  echo "[INFO] Pulling $container ..."
  ${PODMAN} pull ${ARCH_OVERRIDE} $container 2>&1
fi

# create local container
${PODMAN} rm -f "${tmpcontainer}" 2>&1 >/dev/null || true
# use sh for regular containers or ls for scratch containers
${PODMAN} create --name="${tmpcontainer}" $container sh 2>&1 >/dev/null || ${PODMAN} create --name="${tmpcontainer}" $container ls 2>&1 >/dev/null 

# export and unpack
${PODMAN} export "${tmpcontainer}" > /tmp/${tmpcontainer}.tar
rm -fr "$unpackdir"; mkdir -p "$unpackdir"
echo "[INFO] Extract from container ..."
tar xf /tmp/${tmpcontainer}.tar --wildcards -C "$unpackdir" ${TAR_FLAGS}

# cleanup
${PODMAN} rm -f "${tmpcontainer}" 2>&1 >/dev/null || true
rm -fr  /tmp/${tmpcontainer}.tar

echo "[INFO] Container $container unpacked to $unpackdir"
