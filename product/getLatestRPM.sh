#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# use this script to compute the latest rpm for a given pattern, and update Dockerfiles with that latest version
# intent here is to stay current w/ latest RPM (eg., openshift-clients or helm without running into situation where the same version of RPM doesn't exist for all arches)

# TODO read this from container.yaml next to Dockerfile?, eg., ARCHES=$(yq -r '.platforms.only[]' container.yaml)
ARCHES="x86_64 s390x ppc64le"

QUIET=0 # if 0, echo what's happening; if 1, echo only the new version found and replaced

# collect params
while [[ "$#" -gt 0 ]]; do
  case $1 in
  '-r') RPM_PATTERN="$2"; shift 1;; # eg., openshift-clients or helm
  '-s') SOURCE_DIR="$2"; shift 1;; # dir to search for Dockerfiles
  '-a') ARCHES="$ARCHES $2"; shift 1;; # use space-separated list of arches, or use multiple -a flags
  '-u') BASE_URL="$2"; shift 1;; # eg., http://pulp.dist.prod.ext.phx2.redhat.com/content/dist/layered/rhel8/basearch/rhocp/4.7
  '-q') QUIET=1; shift 0;;
  '-h') usage;;
  esac
  shift 1
done

usage () {
  echo "
Usage: 
  $0 -s SOURCE_DIR -r RPM_PATTERN  -u BASE_URL -a 'ARCH1 ... ARCHN' 
Example: 
  $0 -s /path/to/dockerfiles/ -r openshift-clients-4 -u http://pulp.dist.prod.ext.phx2.redhat.com/content/dist/layered/rhel8/basearch/rhocp/4.7
  $0 -s /path/to/dockerfiles/ -r helm-3              -u http://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/basearch/ocp-tools/4.7
Options:
  -q quieter output; only reports changed rpm version or 0 if failure
"
}
if [[ ! ${RPM_PATTERN} ]] || [[ ! ${SOURCE_DIR} ]] || [[ ! ${BASE_URL} ]]; then usage; fi

# find Dockerfiles to update
dockerfiles=$(find ${SOURCE_DIR} -type f -name "*ockerfile")

# compute latest version that spans all ARCHES
declare -A versions=()
for arch in $ARCHES; do
    checkURL=${BASE_URL/basearch/${arch}}/os/Packages/${RPM_PATTERN:0:1}/
    if [[ $QUIET -eq 0 ]]; then echo "[INFO] Load $arch versions from ${checkURL}"; fi
    thisarchversions=$(curl --retry 10 -sSLo- ${checkURL} | grep -E "${RPM_PATTERN}" | sed -r -e "s#.+href=\"(.+).${arch}.rpm\">.+#\1#")
    if [[ ! $thisarchversions ]]; then 
        if [[ $QUIET -eq 0 ]]; then 
            echo "[ERROR] failed to load ${checkURL} !"
        else
            echo "0"
        fi
        exit 1
    fi
    for thisver in $thisarchversions; do
    # echo "[DEBUG] Found ${thisver} for ${arch}"
    versions[${thisver}]+="$arch "
    done
done
# sort keys
sorted=()
while IFS= read -rd '' key; do
    sorted+=( "$key" )
done < <(printf '%s\0' "${!versions[@]}" | sort -zr)
# find first good key w/ all required arches
for i in "${sorted[@]}"; do
    versions[$i]=$(echo ${versions[$i]} | xargs) # trim and condense separator spaces
    # echo "[DEBUG] $i: '${versions[$i]}'"
    if [[ "${versions[$i]}" == "${ARCHES}" ]]; then # found largest version for all required arches
        newVersion=${i}
        break 1;
    fi
done

# update Dockerfiles
for d in $dockerfiles; do
  # echo "[DEBUG] Checking $d ..."
  if [[ $(grep -E "${RPM_PATTERN}" $d) ]]; then
    # echo "[Debug] Dockerfile contains ${RPM_PATTERN} ..."
    if [[ $QUIET -eq 0 ]]; then echo "[INFO] $RPM_PATTERN -> $newVersion in $d"; fi
    sed -i $d -r -e "s#(/| )(${RPM_PATTERN}[^ ]+.el8)#\1$newVersion#g"
  fi
done

# TODO update content_sets.* files too, if ocp version has changed

# just echo the version we found and changed if we're in quiet mode
if [[ $QUIET -eq 1 ]]; then echo $newVersion; fi
