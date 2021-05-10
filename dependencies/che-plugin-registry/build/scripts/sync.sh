#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
# convert plugin registry upper-midstream (crw repo, forked from upstream w/ different plugins) to lower-midstream (crw-images repo) using yq, sed

set -e

SCRIPTS_DIR=$(cd "$(dirname "$0")"; pwd)

# defaults
CSV_VERSION=2.y.0 # csv 2.y.0
CRW_VERSION=${CSV_VERSION%.*} # tag 2.y

usage () {
    echo "
Usage:   $0 -v [CRW CSV_VERSION] [-s /path/to/sources] [-t /path/to/generated]
Example: $0 -v 2.y.0 -s ${HOME}/codeready-workspaces/dependencies/che-plugin-registry -t /tmp/codeready-workspaces-images/codeready-workspaces-pluginregistry
"
    exit
}

if [[ $# -lt 6 ]]; then usage; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    # for CSV_VERSION = 2.2.0, get CRW_VERSION = 2.2
    '-v') CSV_VERSION="$2"; CRW_VERSION="${CSV_VERSION%.*}"; shift 1;;
    # paths to use for input and ouput
    '-s') SOURCEDIR="$2"; SOURCEDIR="${SOURCEDIR%/}"; shift 1;;
    '-t') TARGETDIR="$2"; TARGETDIR="${TARGETDIR%/}"; shift 1;;
    '--help'|'-h') usage;;
    # optional tag overrides
  esac
  shift 1
done

if [ "${CSV_VERSION}" == "2.y.0" ]; then usage; fi

# step one - build the builder image
BUILDER=$(command -v podman || true)
if [[ ! -x $BUILDER ]]; then
  echo "[WARNING] podman is not installed, trying with docker"
  BUILDER=$(command -v docker || true)
  if [[ ! -x $BUILDER ]]; then
      echo "[ERROR] must install docker or podman. Abort!"; exit 1
  fi
fi

# global / generic changes
echo ".github/
.git/
.gitattributes
build/scripts/sync.sh
get-sources-jenkins.sh
container.yaml
content_sets.yml
" > /tmp/rsync-excludes
echo "Rsync ${SOURCEDIR} to ${TARGETDIR}"
rsync -azrlt --checksum --exclude-from /tmp/rsync-excludes --delete ${SOURCEDIR}/ ${TARGETDIR}/
rm -f /tmp/rsync-excludes

# CRW-1792 transform che-editors.yaml#L5 and che-plugins.yaml#L3 to refer to /latest
pushd "${TARGETDIR}" >/dev/null || exit 1
for d in che-editors.yaml che-plugins.yaml; do 
    sed -i ${d} -r -e "s|/nightly|/latest|" -e "s|/next|/latest|"
done
popd >/dev/null || exit

# transform Dockefile
sed "${TARGETDIR}/build/dockerfiles/Dockerfile" --regexp-extended \
    `# Replace image used for registry with rhel8/httpd-24` \
    -e 's|^ *FROM registry.access.redhat.com/.* AS registry|# &|' \
    -e 's|# *(FROM.*rhel8/httpd.*)|\1|' \
    -e 's|^ *(FROM rhscl/httpd.*)|#\1|' \
    `# Strip registry from image references` \
    -e 's|FROM registry.access.redhat.com/|FROM |' \
    -e 's|FROM registry.redhat.io/|FROM |' \
    `# Set arg options: enable USE_DIGESTS and disable BOOTSTRAP` \
    -e 's|ARG USE_DIGESTS=.*|ARG USE_DIGESTS=true|' \
    -e 's|ARG BOOTSTRAP=.*|ARG BOOTSTRAP=false|' \
    `# Enable offline build - copy in built binaries` \
    -e 's|# (COPY root-local.tgz)|\1|' \
    `# only enable rhel8 here -- don't want centos or epel ` \
    -e 's|^ *(COPY .*)/content_set.*repo (.+)|\1/content_sets_rhel8.repo \2|' \
    `# Comment out PATCHED_* args from build and disable update_devfile_patched_image_tags.sh` \
    -e 's|^ *ARG PATCHED.*|# &|' \
    -e '/^ *RUN TAG/,+3 s|.*|# &| ' \
    `# Disable intermediate build targets` \
    -e 's|^ *FROM registry AS offline-registry|# &|' \
    -e '/^ *FROM builder AS offline-builder/,+3 s|.*|# &|' \
    -e 's|^[^#]*--from=offline-builder.*|# &|' \
    `# Enable cache_artifacts.sh` \
    -e '\|swap_images.sh|i # Cache projects in CRW \
COPY ./build/dockerfiles/rhel.cache_artifacts.sh resources.tgz /tmp/ \
RUN /tmp/rhel.cache_artifacts.sh /build/v3/ && rm -rf /tmp/rhel.cache_artifacts.sh /tmp/resources.tgz \
' > "${TARGETDIR}/Dockerfile"

cat << EOT >> "${TARGETDIR}/Dockerfile"
ENV SUMMARY="Red Hat CodeReady Workspaces pluginregistry container" \\
    DESCRIPTION="Red Hat CodeReady Workspaces pluginregistry container" \\
    PRODNAME="codeready-workspaces" \\
    COMPNAME="pluginregistry-rhel8"
LABEL summary="$SUMMARY" \\
      description="\$DESCRIPTION" \\
      io.k8s.description="\$DESCRIPTION" \\
      io.k8s.display-name="\$DESCRIPTION" \\
      io.openshift.tags="\$PRODNAME,\$COMPNAME" \\
      com.redhat.component="\$PRODNAME-\$COMPNAME-container" \\
      name="\$PRODNAME/\$COMPNAME" \\
      version="${CRW_VERSION}" \\
      license="EPLv2" \\
      maintainer="Eric Williams <ericwill@redhat.com>, Nick Boldt <nboldt@redhat.com>" \\
      io.openshift.expose-services="" \\
      usage=""
EOT
echo "Converted Dockerfile"

# header to reattach to yaml files after yq transform removes it
COPYRIGHT="#
#  Copyright (c) 2021 Red Hat, Inc.
#    This program and the accompanying materials are made
#    available under the terms of the Eclipse Public License 2.0
#    which is available at https://www.eclipse.org/legal/epl-2.0/
#
#  SPDX-License-Identifier: EPL-2.0
#
#  Contributors:
#    Red Hat, Inc. - initial API and implementation
"

replaceField()
{
  theFile="$1"
  updateName="$2"
  updateVal="$3"
  echo "[INFO] ${0##*/} :: * ${updateName}: ${updateVal}"
  changed=$(cat ${theFile} | yq -Y --arg updateName "${updateName}" --arg updateVal "${updateVal}" \
    ${updateName}' = $updateVal')
  echo "${COPYRIGHT}${changed}" > "${theFile}"
}

pushd ${TARGETDIR} >/dev/null || exit 1

# TODO transform che-theia references to CRW theia references, including:
# descritpion, icon, attributes.version, attributes.title, attributes.repository


popd >/dev/null || exit
