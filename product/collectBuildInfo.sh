#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to collect create/start/finish data on OSBS tasks. Pass in param: taskid
# requires: brew/koji rpm to be installed

# 	 Store data as yaml, with option to convert to csv
# 	  * container that was built (incl. tag)
# 	  	  $➔ curl -sSLo- https://download.eng.bos.redhat.com/brewroot/work/tasks/4137/48564137/x86_64.log | tail -2 | sed -r -e "s@.+containers/#/(.+)\"@\1@" | head -1
# 	  * dates

# --------
# $➔ brew taskinfo 48564137 | grep -E "Created|Started|Finished"
# Created: Tue Oct 25 12:39:21 2022
# Started: Tue Oct 25 15:40:08 2022
# Finished: Tue Oct 25 15:45:50 2022
# --------

TASK_ID=""    # required, task id from brew/osbs
OUTPUT_YML="" # required, path and filename to update
OUTPUT_CSV="" # optional, also write to CSV file
APPEND=0      # by default, create a new yml / csv file

usage () {
	echo "
Usage: 
  $0 [-t TASK_ID | -b BUILD_ID] [OPTIONS]

Options:
  -t              Collect data for a given Task ID
  -b              Collect data for a given Build ID
  -f              Optionally, write to /path/to/output.yaml
  --csv           Optionally, also write to /path/to/output.csv
  --append        When writing to .yaml file (and .csv file), append instead of overwriting

Example - collect metadata for the current builds in 
https://github.com/redhat-developer/devspaces/blob/devspaces-3-rhel-8/dependencies/LATEST_IMAGES_COMMITS:

    for d in $(cat /path/to/LATEST_IMAGES_COMMITS | grep Build | sed -r -e "s@.+buildID=@@"); do \
      $0 -b $d --append -f /tmp/collectBuildInfo.yml --csv /tmp/collectBuildInfo.csv ; \
    done

"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') TASK_ID="$2"; shift 1;;
    '-b') BUILD_ID="$2"; shift 1;;
    '-f') OUTPUT_YML="$2"; shift 1;;
    '--csv') OUTPUT_CSV="$2"; shift 1;;
    '--append') APPEND=1;;
    '--help') usage; exit;; 
  esac
  shift 1
done

if [[ -z ${TASK_ID} ]] && [[ -z ${BUILD_ID} ]]; then usage; exit 1; fi

# date diffs based on https://unix.stackexchange.com/questions/24626/quickly-calculate-date-differences
datediff() {
    d1=$(date -d "$1" +%s)
    d2=$(date -d "$2" +%s)
    echo $(( (d2 - d1) / 60 )) minutes
}

getTaskIDFromBuildID () {
    TASK_ID=$(brew buildinfo $BUILD_ID | grep container_koji_task_id | sed -r -e "s@.+'container_koji_task_id': ([0-9]+),.+@\1@")
    echo $TASK_ID
}

getContainerFromTaskID () {
    if [[ $BUILD_ID ]]; then
        getContainerFromBuildID $BUILD_ID
    else
        # curl -sSLo- https://download.eng.bos.redhat.com/brewroot/work/tasks/4137/48564137/x86_64.log | tail -2 | sed -r -e "s@.+containers/#/(.+)\"@\1@" | head -1
        taskid=$1
        log="https://download.eng.bos.redhat.com/brewroot/work/tasks/${taskid:(-4)}/${taskid}/x86_64.log"
        container=$(curl -sSLko- $log | tail -2 | sed -r -e "s@.+containers/#/(.+)\"@\1@" -e "s@/images/@:@" -e "s@registry.access.redhat.com/@@" | head -1)
        echo $container
    fi
}

getContainerFromBuildID () {
# brew buildinfo 2203173 | grep Extra | sed -r -e "s@Extra: @@" | yq -r '.image.index.pull[]' | grep -v sha256
# registry-proxy.engineering.redhat.com/rh-osbs/devspaces-code-rhel8:3.3-6
    buildid=$1
    container=$(brew buildinfo $buildid | grep Extra | sed -r -e "s@Extra: @@" | yq -r '.image.index.pull[]' | grep -v sha256 \
        | sed -r -e "s@registry-proxy.engineering.redhat.com/rh-osbs/@@")
    echo $container
}

getADate() {
    name=$1
    result=$(echo "$dates" | grep "$name" | sed -r -e "s@$name: @@")
    echo $result
}

if [[ $BUILD_ID ]]; then
    echo -n "For Build ID = $BUILD_ID: "; # getContainerFromBuildID $BUILD_ID
    TASK_ID=$(getTaskIDFromBuildID $BUILD_ID)
    if [[ $TASK_ID ]]; then echo "Task ID = $TASK_ID"; else echo "[ERROR] could not compute Task ID for this Build ID"; exit 2; fi
fi
echo -n "For Task ID = $TASK_ID: "; getContainerFromTaskID $TASK_ID
dates="$(brew taskinfo $TASK_ID | grep -E "Created|Started|Finished")"
timeCreate=$(getADate Created) 
timeStart=$(getADate Started) 
timeFinish=$(getADate Finished)
timeWait=$(datediff  "$timeCreate" "$timeStart")
timeBuild=$(datediff "$timeStart"  "$timeFinish")
timeTotal=$(datediff "$timeCreate" "$timeFinish")

yaml="- name: ${container%:*}
  tag: ${container#*:}
  taskId: $TASK_ID
  timeCreate: ${timeCreate}
  timeStart: ${timeStart}
  timeFinish: ${timeFinish}
  timeWait: ${timeWait}
  timeBuild: ${timeBuild}
  timeTotal: ${timeTotal}
"

echo "$yaml"
if [[ $OUTPUT_YML ]]; then
    if [[ $APPEND -eq 1 ]]; then
        echo "$yaml" >> $OUTPUT_YML
    else
        echo "$yaml" > $OUTPUT_YML
    fi
    if [[ $OUTPUT_CSV ]]; then 
        cat $OUTPUT_YML | yq -r '.[]|(keys_unsorted)|@csv' | uniq > $OUTPUT_CSV
        yq -r '.[]|flatten|@csv' $OUTPUT_YML >> $OUTPUT_CSV
    fi
fi
