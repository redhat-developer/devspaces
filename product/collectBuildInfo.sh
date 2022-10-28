#!/bin/bash
#
# Copyright (c) 2022 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to collect create/start/finish data on OSBS tasks. 

TASK_ID=""    # required, task id from brew/osbs
OUTPUT_YML="" # required, path and filename to update
OUTPUT_CSV="" # optional, also write to CSV file
APPEND=0      # by default, create a new yml / csv file
SORT=1        # by default, sort by taskId descending
VERBOSE=0     # by default, be quiet

usage () {
	echo "
Usage: 
  $0 [-t TASK_ID | -b BUILD_ID] [OPTIONS]

Options:
  -t               Collect data for a given Task ID
  -b               Collect data for a given Build ID
  -f               Optionally, write to /path/to/output.yaml
  --csv            Optionally, also write to /path/to/output.csv
  --append         When writing to .yaml file (and .csv file), append instead of overwriting
  --unsorted       Don't sort chronologically by taskId descending
  -v, --verbose    Verbose output: include additional information
  -h, --help       Show this help

Example - collect metadata for the current builds in 
https://github.com/redhat-developer/devspaces/blob/devspaces-3-rhel-8/dependencies/LATEST_IMAGES_COMMITS:

    for d in \$(cat /path/to/LATEST_IMAGES_COMMITS | grep Build | sed -r -e "s@.+buildID=@@"); do \\
      $0 -b \$d --append -f /tmp/collectBuildInfo.yml --csv /tmp/collectBuildInfo.csv ; \\
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
    '--unsorted') SORT=0;;
    '-v'|'--verbose') VERBOSE=1;;
    '-h'|'--help') usage;;
    *) echo "Unknown parameter used: $1."; usage; exit 1;;
  esac
  shift 1
done

if [[ -z ${TASK_ID} ]] && [[ -z ${BUILD_ID} ]]; then usage; exit 1; fi

# date diffs based on https://unix.stackexchange.com/questions/24626/quickly-calculate-date-differences
datediff() {
    d1=$(date -d "$1" +%s)
    d2=$(date -d "$2" +%s)
    echo -n "$(( (d2 - d1) / 60 )) mins"
}

getTaskIDFromBuildID () {
    TASK_ID=$(brew buildinfo $BUILD_ID | grep container_koji_task_id | sed -r -e "s@.+'container_koji_task_id': ([0-9]+),.+@\1@")
    echo -n $TASK_ID
}

getContainerFromTaskID () {
    if [[ $BUILD_ID ]]; then
        getContainerFromBuildID $BUILD_ID
    else
        # curl -sSLo- https://download.eng.bos.redhat.com/brewroot/work/tasks/4137/48564137/x86_64.log | tail -2 | sed -r -e "s@.+containers/#/(.+)\"@\1@" | head -1
        taskid=$1
        log="https://download.eng.bos.redhat.com/brewroot/work/tasks/${taskid:(-4)}/${taskid}/x86_64.log"
        container=$(curl -sSLko- $log | tail -2 | sed -r -e "s@.+containers/#/(.+)\"@\1@" -e "s@/images/@:@" -e "s@registry.access.redhat.com/@@" | head -1)
        echo -n $container
    fi
}

getContainerFromBuildID () {
# brew buildinfo 2203173 | grep Extra | sed -r -e "s@Extra: @@" | yq -r '.image.index.pull[]' | grep -v sha256
# registry-proxy.engineering.redhat.com/rh-osbs/devspaces-code-rhel8:3.3-6
    buildid=$1
    container=$(brew buildinfo $buildid | grep Extra | sed -r -e "s@Extra: @@" | yq -r '.image.index.pull[]' | grep -v sha256 \
        | sed -r -e "s@registry-proxy.engineering.redhat.com/rh-osbs/@@")
    echo -n $container
}

getADate() {
    name=$1
    result=$(echo "$dates" | grep "$name" | sed -r -e "s@$name: @@")
    echo $result
}

if [[ $BUILD_ID ]]; then
    if [[ $VERBOSE -eq 1 ]]; then
        echo -n "For Build ID = $BUILD_ID: "; # getContainerFromBuildID $BUILD_ID
    fi
    TASK_ID=$(getTaskIDFromBuildID $BUILD_ID)
    if [[ $TASK_ID ]]; then 
        if [[ $VERBOSE -eq 1 ]]; then
            echo "Task ID = $TASK_ID"
        fi
    else 
        echo "[ERROR] could not compute Task ID for this Build ID"; exit 2
    fi
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
if [[ $VERBOSE -eq 1 ]]; then
    echo;echo "$yaml"
fi
if [[ -f $OUTPUT_YML ]]; then touch $OUTPUT_YML; fi
if [[ $(grep "  taskId: $TASK_ID" $OUTPUT_YML) ]]; then
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[INFO] Skip: taskId $TASK_ID already in $OUTPUT_YML"; echo
    else 
        echo " - skipped"
    fi
else
    if [[ $OUTPUT_YML ]]; then
        if [[ $VERBOSE -eq 0 ]]; then echo; fi

        if [[ $APPEND -eq 1 ]]; then
            echo "$yaml" >> $OUTPUT_YML
        else
            echo "$yaml" > $OUTPUT_YML
        fi

        # sorting removes spaces between yaml entries
        if [[ $SORT -eq 1 ]]; then
            # sort yaml by taskId (most recent tasks at the end of the file)
            yq -Y -i '.|=sort_by(.taskId)' $OUTPUT_YML
        fi

        if [[ $OUTPUT_CSV ]]; then 
            if [[ $SORT -eq 1 ]]; then
                # always replace csv file with fresh content from the yaml file
                cat $OUTPUT_YML | yq -r '.[]|(keys_unsorted)|@csv' | uniq > $OUTPUT_CSV
                cat $OUTPUT_YML | yq -r '.[]|flatten|@csv' >> $OUTPUT_CSV
            else
                # add header if needed (file doesn't exist or is empty)
                if [[ ! -f $OUTPUT_CSV ]] || [[ ! -s $OUTPUT_CSV ]]; then
                    cat $OUTPUT_YML | yq -r '.[]|(keys_unsorted)|@csv' | uniq > $OUTPUT_CSV
                fi
                # add the new yaml as a line of csv
                echo "$yaml" | yq -r '.[]|flatten|@csv' >> $OUTPUT_CSV
            fi
        fi

        if [[ $VERBOSE -eq 1 ]]; then
            echo "[INFO] Wrote info to $OUTPUT_YML"
            if [[ $OUTPUT_CSV ]]; then echo "[INFO] Wrote info to $OUTPUT_CSV"; fi
            echo
        fi
    fi
fi
