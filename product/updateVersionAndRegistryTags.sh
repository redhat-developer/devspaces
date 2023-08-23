#!/bin/bash
#
# Copyright (c) 2021-2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# set newer version across the DEVSPACES repository in dependencies/VERSION file and registry image tags

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")

PR_BRANCH="pr-update-version-and-registry-tags-$(date +%s)"
OPENBROWSERFLAG="" # if a PR is generated, open it in a browser
docommit=1 # by default DO commit the change
dopush=1 # by default DO push the change
WORKDIR="$(pwd)"
REMOVE_DEVSPACES_VERSION=""
ENABLE_DEVSPACES_JOBS_VERSION=""
ENABLE_DEVSPACES_MGMTJOBS_VERSION=""
DISABLE_DEVSPACES_JOBS_VERSION=""
DISABLE_DEVSPACES_MGMTJOBS_VERSION=""
BRANCH="devspaces-3-rhel-8"

# for DS 3.y = 3.8 Che is 7.72 
# For DS 3.9+ We are moving to 3 week sprints so the math is changing again.
# 3.9 => (9 * 2) + 56 = 74 ==> 7.74
# 3.10 => (10 * 2) + 56 = 76 ==> 7.76
CHE_OFFSET=56

usage () {
  echo "
Usage:   $0 -v [DEVSPACES CSV_VERSION] [-t DEVSPACES_VERSION]
Example: $0 -v 3.yy.0 # use CSV version
Example: $0 -t 3.yy   # use tag version

Options:
  --help, -h              help
  -w WORKDIR              work in a different dir than $(pwd)
  -b BRANCH               commit to a different branch than $BRANCH
  -t DEVSPACES_VERSION          use a specific tag; by default, compute from CSV_VERSION
  --no-commit, -n         do not commit or push to BRANCH
  --no-push, -p           do not push to BRANCH
  -prb                    set a PR_BRANCH; default: pr-update-version-and-registry-tags-(timestamp)
  -o                      open browser if PR generated
  
  --remove [DEVSPACES_VERSION]                  remove data for [DEVSPACES_VERSION] (Example: for .Version = 3.yy, delete 3.yy-2)
  --enable-jobs [DEVSPACES_VERSION]             enable [DEVSPACES_VERSION] jobs in job-config.json, but leave bundle + management jobs alone
  --enable-management-jobs [DEVSPACES_VERSION]  enable ALL [DEVSPACES_VERSION] jobs in job-config.json
  --disable-jobs [DEVSPACES_VERSION]            disable [DEVSPACES_VERSION] jobs in job-config.json, but leave bundle + management jobs alone
  --disable-management-jobs [DEVSPACES_VERSION] disable ALL [DEVSPACES_VERSION] jobs in job-config.json (implement code freeze)
  "
}

if [[ $# -lt 1 ]]; then usage; exit; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-w') WORKDIR="$2"; shift 1;;
    '-b') BRANCH="$2"; shift 1;;
    '-v') CSV_VERSION="$2"; shift 1;; # 3.y.0
    '-t') DEVSPACES_VERSION="$2"; shift 1;; # 3.y
    '-n'|'--no-commit') docommit=0; dopush=0; shift 0;;
    '-p'|'--no-push') dopush=0; shift 0;;
    '-prb') PR_BRANCH="$2"; shift 1;;
    '-o') OPENBROWSERFLAG="-o"; shift 0;;
    '--remove') REMOVE_DEVSPACES_VERSION="$2"; shift 1;;
    '--enable-jobs') ENABLE_DEVSPACES_JOBS_VERSION="$2"; shift 1;;
    '--enable-management-jobs') ENABLE_DEVSPACES_MGMTJOBS_VERSION="$2"; shift 1;;
    '--disable-jobs') DISABLE_DEVSPACES_JOBS_VERSION="$2"; shift 1;;
    '--disable-management-jobs') DISABLE_DEVSPACES_MGMTJOBS_VERSION="$2"; shift 1;;
    '--help'|'-h') usage; exit;;
    *) OTHER="${OTHER} $1"; shift 0;;
  esac
  shift 1
done

if [[ ! ${DEVSPACES_VERSION} ]]; then
  DEVSPACES_VERSION=${CSV_VERSION%.*} # given 3.y.0, want 3.y
fi

COPYRIGHT="#
# Copyright (c) 2018-$(date +%Y) Red Hat, Inc.
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
  # shellcheck disable=SC2016 disable=SC2002 disable=SC2086
  if [[ ${theFile} == *".json" ]]; then
    changed=$(cat "${theFile}" | jq ${updateName}' |= '"$updateVal")
    echo "${changed}" > "${theFile}"
  elif [[ ${theFile} == *".yml" ]] || [[ ${theFile} == *".yaml" ]]; then
    changed=$(cat "${theFile}" | yq -Y --arg updateName "${updateName}" --arg updateVal "${updateVal}" ${updateName}' = $updateVal')
    echo "${COPYRIGHT}${changed}" > "${theFile}"
  fi
}

computeLatestCSV() {
  image=$1 # operator-bundle
  SOURCE_CONTAINER=registry.redhat.io/devspaces/devspaces-${image}
  containerTag=$(skopeo inspect docker://${SOURCE_CONTAINER} 2>/dev/null | jq -r '.Labels.url' | sed -r -e "s#.+/images/##")
  echo "Found containerTag = ${containerTag}"

  # extract the CSV version from the container as with CVE respins, the CSV version != the nominal container tag or JIRA version 2.13.1
  if [[ ! -x ${SCRIPTPATH}/containerExtract.sh ]]; then
      curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/devspaces-3-rhel-8/product/containerExtract.sh
      chmod +x containerExtract.sh
  fi
  rm -fr /tmp/${SOURCE_CONTAINER//\//-}-${containerTag}-*/
  ${SCRIPTPATH}/containerExtract.sh ${SOURCE_CONTAINER}:${containerTag} --delete-before --delete-after 2>&1 >/dev/null || true
  if [[ ! -f $(find /tmp/${SOURCE_CONTAINER//\//-}-${containerTag}-*/manifests -name devspaces.csv.yaml) ]]; then
    echo "[WARN] Container ${SOURCE_CONTAINER}:${containerTag} could not be extracted!"
  else 
    grep -E "devspacesoperator|replaces:" /tmp/${SOURCE_CONTAINER//\//-}-${containerTag}-*/manifests/devspaces.csv.yaml 
    CSV_VERSION_PREV=$(yq -r '.spec.version' /tmp/${SOURCE_CONTAINER//\//-}-${containerTag}-*/manifests/devspaces.csv.yaml 2>/dev/null | tr "+" "-")
    rm -fr /tmp/${SOURCE_CONTAINER//\//-}-${containerTag}-*/
  fi

  # CRW-4324, CRW-4354 DO NOT keep freshmaker suffix for previous CSV versions!!! 
  # Using FM versions WILL break CVP tests when the image doesn't exist for all OCP versions or hasn't been released yet to RHEC (which happens intermittently)
  # We ship using open-ended OCP version range: see com.redhat.openshift.versions 
  # in https://github.com/redhat-developer/devspaces-images/blob/devspaces-3-rhel-8/devspaces-operator-bundle/Dockerfile#L31)
  # We must assume that the Freshmaker lifecycle will do its own thing with olm.substitutesFor (grafting their fixes onto our single-stream graph) rather than injecting itself into our graph directly and pruning out older releases
  # See also https://issues.redhat.com/browse/CWFHEALTH-2003 https://issues.redhat.com/browse/CLOUDWF-9099 https://issues.redhat.com/browse/CLOUDDST-18632
  echo "Found CSV_VERSION_PREV = ${CSV_VERSION_PREV}"
  CSV_VERSION_PREV=${CSV_VERSION_PREV%-*.p} # remove freshmaker suffix
  echo "Using CSV_VERSION_PREV = ${CSV_VERSION_PREV}"

  # update CSVs["${image}"].$version.CSV_VERSION_PREV for current stable version and 3.x versions
  DEVSPACES_VERSION_PREV="${DEVSPACES_VERSION}"
  if [[ $DEVSPACES_VERSION =~ ^([0-9]+)\.([0-9]+) ]]; then # reduce the z digit, remove the snapshot suffix
    XX=${BASH_REMATCH[1]}
    YY=${BASH_REMATCH[2]}
    let YY=YY-1 || YY=0; if [[ $YY -lt 0 ]]; then YY=0; fi # if result of a let == 0, bash returns 1
    DEVSPACES_VERSION_PREV="${XX}.${YY}"
    COMMIT_MSG="${COMMIT_MSG}; update previous CSV to ${CSV_VERSION_PREV} for ${DEVSPACES_VERSION_PREV}+"
    replaceField "${WORKDIR}/dependencies/job-config.json" "(.CSVs[\"${image}\"][\"${DEVSPACES_VERSION_PREV}\"].CSV_VERSION_PREV)" "\"${CSV_VERSION_PREV}\""
  else
    COMMIT_MSG="${COMMIT_MSG}; update previous CSV to ${CSV_VERSION_PREV} for ${DEVSPACES_VERSION}+"
  fi
  replaceField "${WORKDIR}/dependencies/job-config.json" "(.CSVs[\"${image}\"][\"${DEVSPACES_VERSION}\"].CSV_VERSION_PREV)" "\"${CSV_VERSION_PREV}\""
  replaceField "${WORKDIR}/dependencies/job-config.json" "(.CSVs[\"${image}\"][\"3.x\"].CSV_VERSION_PREV)" "\"${CSV_VERSION_PREV}\""
}

# for a given DEVSPACES version, compute the equivalent Che versions that could be compatible 
computeLatestPackageVersion() {
    found=0
    BASE_VERSION="$1" # Dev Spaces 3.y version to use for computations
    packageName="$2"
    THIS_Y_VALUE="${BASE_VERSION#*.}"; 
    # 3.7 and 3.8 are both different so hardcode and we can take them out as they become irrelevant
    # note that these values are used for versions where main doesn't make sense, such as  @eclipse-che/plugin-registry-generator
    if [[ $THIS_Y_VALUE -eq 8 ]]; then # Check DS 3.8 first, will be relevant longer.
      THIS_CHE_Y=72
      THIS_CHE_Y_LOWER=71
    elif [[ $THIS_Y_VALUE -eq 7 ]]; then # DS 3.7 Mapping
      THIS_CHE_Y=67
      THIS_CHE_Y_LOWER=66
    else # DS 3.9+ Mapping
      THIS_CHE_Y=$(( (${THIS_Y_VALUE} * 2) + ${CHE_OFFSET} )); 
      THIS_CHE_Y_LOWER=$(( ${THIS_CHE_Y} - 1 ));
      # echo "For THIS_Y_VALUE = $THIS_Y_VALUE, got THIS_CHE_Y = $THIS_CHE_Y and THIS_CHE_Y_LOWER = $THIS_CHE_Y_LOWER"
    fi

    # check if .2, .1, .0 version exists in npmjs.com
    for y in $THIS_CHE_Y $THIS_CHE_Y_LOWER; do 
      for z in 2 1 0; do 
        # echo "curl -sSI https://www.npmjs.com/package/${packageName}/v/7.${y}.${z}"
        if [[ $(curl -sSI "https://www.npmjs.com/package/${packageName}/v/7.${y}.${z}" | grep 404) != *"404"* ]]; then
        change="plugin-registry-generator[$BASE_VERSION] = 7.${y}.${z}"
        COMMIT_MSG="${COMMIT_MSG}; update $change"
          echo "Update $change"
          replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"${packageName}\"][\"${BASE_VERSION}\"]" "\"7.${y}.${z}\""
          found=1
          break 2
        fi
      done
    done
    if [[ $found -eq 0 ]]; then
      replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"${packageName}\"][\"${BASE_VERSION}\"]" "\"latest\""
    fi
}

# update job-config file to product version (x.y)
COMMIT_MSG=""
updateVersion() {
    # deprecated, @since 2.11
    echo "${DEVSPACES_VERSION}" > "${WORKDIR}/dependencies/VERSION"
    # @since 2.11
    replaceField "${WORKDIR}/dependencies/job-config.json" '.Version' "${DEVSPACES_VERSION}"
    replaceField "${WORKDIR}/dependencies/job-config.json" '.Copyright' "[\"${COPYRIGHT}\"]"

    DEVSPACES_Y_VALUE="${DEVSPACES_VERSION#*.}"

    # for 3.7, want 7.67, 7.66 (ignore 7.65)
    # for 3.8, want 7.72 or main if 7.72 hasn't been released
    # for 3.9, want 7.74 or main 
    if [[ $DEVSPACES_Y_VALUE -eq 8 ]]; then
      CHE_Y=72
    elif [[ $DEVSPACES_Y_VALUE -eq 7 ]]; then
      CHE_Y=67
    else
      CHE_Y=$(( (${DEVSPACES_Y_VALUE} * 2 ) + ${CHE_OFFSET} ))
      # echo "For DEVSPACES_Y_VALUE = $DEVSPACES_Y_VALUE, got CHE_Y = $CHE_Y"
    fi
    # CRW-2155, if version is in the json update it for che and devspaces branches
    # otherwise inject new version.
    check=$(cat ${WORKDIR}/dependencies/job-config.json | jq '.Jobs[] | keys' | grep "\"${DEVSPACES_VERSION}\"")
    if [[ ${check} ]]; then #just updating
      COMMIT_MSG="ci: update ${DEVSPACES_VERSION}"
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?|contains(\".x\")))" "[\"7.${CHE_Y}.x\",\"main\"]"
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"devspaces-3-rhel-8\"))" "[\"devspaces-${DEVSPACES_VERSION}-rhel-8\",\"devspaces-${DEVSPACES_VERSION}-rhel-8\"]"

      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?|contains(\".x\")))" "[\"7.${CHE_Y}.x\",\"main\"]"
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"devspaces-3-rhel-8\"))" "[\"devspaces-${DEVSPACES_VERSION}-rhel-8\",\"devspaces-${DEVSPACES_VERSION}-rhel-8\"]"

      #make sure jobs are enabled
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${DEVSPACES_VERSION}\"][\"disabled\"]|select(.==true))" 'false'
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${DEVSPACES_VERSION}\"][\"disabled\"]|select(.==true))" 'false'
      #remove version if desired
      if [[ $REMOVE_DEVSPACES_VERSION ]]; then
        replaceField "${WORKDIR}/dependencies/job-config.json" "." "del(..|.[\"${REMOVE_DEVSPACES_VERSION}\"]?)"
      fi
    else
      COMMIT_MSG="ci: add new ${DEVSPACES_VERSION}"
      # Get top level keys to start (Jobs, CSVs, Other, etc)
      TOP_KEYS=($(cat ${WORKDIR}/dependencies/job-config.json | jq -r 'keys[]'))

      for TOP_KEY in ${TOP_KEYS[@]}
      do
        if [[ (${TOP_KEY} != "Version") && (${TOP_KEY} != "Copyright") && (${TOP_KEY} != "Purpose") ]]; then
          # Get the sub-keys in Jobs so we can add a new object
          KEYS=($(cat ${WORKDIR}/dependencies/job-config.json | jq -r ".\"${TOP_KEY}\" | keys[]"))

          for KEY in ${KEYS[@]}
          do
            #save content of 3.x
            content=$(cat ${WORKDIR}/dependencies/job-config.json | jq ".\"${TOP_KEY}\"[\"${KEY}\"][\"3.x\"]")
            if [[ $(echo $content | grep "\"") ]]; then #is there a 3.x version
              #Add DEVSPACES_VERSION from 3.x then delete 3.x
              #then append 3.x so the general order remains the same
              replaceField "${WORKDIR}/dependencies/job-config.json" ".\"${TOP_KEY}\"[\"${KEY}\"]" "(. + {\"${DEVSPACES_VERSION}\": .\"3.x\"} | del(.\"3.x\"))"
              replaceField "${WORKDIR}/dependencies/job-config.json" ".\"${TOP_KEY}\"[\"${KEY}\"]" ". + {\"3.x\": ${content}}"

              #while in here remove version if desired
              if [[ $REMOVE_DEVSPACES_VERSION ]]; then
                replaceField "${WORKDIR}/dependencies/job-config.json" ".\"${TOP_KEY}\"[\"${KEY}\"]" "del(.\"${REMOVE_DEVSPACES_VERSION}\")"
              fi
            fi
          done
        fi
      done
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"main\"))" "[\"7.${CHE_Y}.x\",\"main\"]"
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"devspaces-3-rhel-8\"))" "[\"devspaces-${DEVSPACES_VERSION}-rhel-8\",\"devspaces-${DEVSPACES_VERSION}-rhel-8\"]"

      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"main\"))" "[\"7.${CHE_Y}.x\",\"main\"]"
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"devspaces-3-rhel-8\"))" "[\"devspaces-${DEVSPACES_VERSION}-rhel-8\",\"devspaces-${DEVSPACES_VERSION}-rhel-8\"]"

      #make sure new builds are enabled
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${DEVSPACES_VERSION}\"][\"disabled\"]|select(.==true))" 'false'
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${DEVSPACES_VERSION}\"][\"disabled\"]|select(.==true))" 'false'
    fi 

    #find and disable version-2
    #start by gathering all DEVSPACES_VERSIONs that have data in the json
    VERSION_KEYS=($(cat ${WORKDIR}/dependencies/job-config.json | jq -r '.Jobs'[\"dashboard\"]' | keys[]'))
    #get the array index of version -2. length -1 is 3.x, -2 is the version that was added, so the old version that needs to get disabled is length - 4
    DISABLE_VERSION_INDEX=$(( ${#VERSION_KEYS[@]} - 4 )) 

    #Disable version -2, and everything previous (if there)
    while [[ $DISABLE_VERSION_INDEX -gt -1 ]]; do
        VERSION_DISABLE="${VERSION_KEYS[$DISABLE_VERSION_INDEX]}"
        # echo "Disable index = $DISABLE_VERSION_INDEX / $VERSION_DISABLE"
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${VERSION_DISABLE}\"][\"disabled\"]|select(.==false))" 'true'
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${VERSION_DISABLE}\"][\"disabled\"]|select(.==false))" 'true'
        #set the previous 'latest' to be its own version

        # set .2 version of @eclipse-che/plugin-registry-generator if currently set to latest
        if [[ $(jq -r ".Other[\"@eclipse-che/plugin-registry-generator\"][\"${VERSION_DISABLE}\"]" "${WORKDIR}/dependencies/job-config.json") == "latest" ]]; then
          computeLatestPackageVersion $VERSION_DISABLE "@eclipse-che/plugin-registry-generator"
        fi
        DISABLE_VERSION_INDEX=$(( $DISABLE_VERSION_INDEX -1 ))
    done

    #update tags
    replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"FLOATING_QUAY_TAGS\"][\"${DEVSPACES_VERSION}\"]" "\"next\""
    replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"FLOATING_QUAY_TAGS\"][\"3.x\"]" "\"next\""

    #the 'latest' tag should go on the previous/stable version, which would be version -1, or the index 3 form the end of the VERSION_KEYS array
    LATEST_INDEX=$(( ${#VERSION_KEYS[@]} - 3 )); LATEST_VERSION="${VERSION_KEYS[$LATEST_INDEX]}";  echo "LATEST_VERSION = $LATEST_VERSION"

    replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"FLOATING_QUAY_TAGS\"][\"${LATEST_VERSION}\"]" "\"latest\""

    # search for latest released tag to use for stable builds
    computeLatestPackageVersion $LATEST_VERSION "@eclipse-che/plugin-registry-generator"
    # or use "latest" release with replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"@eclipse-che/plugin-registry-generator\"][\"${LATEST_VERSION}\"]" "\"latest\""
    # debug: # cat "${WORKDIR}/dependencies/job-config.json" | grep -E -A5 "FLOATING_QUAY_TAGS|plugin-registry-gen"; exit

    # update CSV versions for 3.yy latest and 3.x too
    echo "DEVSPACES_VERSION = $DEVSPACES_VERSION"
    for op in "operator-bundle"; do
      for ver in "${DEVSPACES_VERSION}" "3.x"; do
        replaceField "${WORKDIR}/dependencies/job-config.json" ".CSVs[\"${op}\"][\"${ver}\"][\"CSV_VERSION\"]" "\"${DEVSPACES_VERSION}.0\""
      done
    done

    # update CSV_VERSION_PREV values
    computeLatestCSV operator-bundle

    # optionally, can enable/disable specific job sets for a given version
    if [[ $ENABLE_DEVSPACES_MGMTJOBS_VERSION ]]; then 
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"$ENABLE_DEVSPACES_MGMTJOBS_VERSION\"][\"disabled\"]|select(.==true))" 'false'
    fi
    if [[ $ENABLE_DEVSPACES_JOBS_VERSION ]]; then 
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"$ENABLE_DEVSPACES_JOBS_VERSION\"][\"disabled\"]|select(.==true))" 'false'
    fi
    if [[ $DISABLE_DEVSPACES_MGMTJOBS_VERSION ]]; then 
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"$DISABLE_DEVSPACES_MGMTJOBS_VERSION\"][\"disabled\"]|select(.==false))" 'true'
    fi
    if [[ $DISABLE_DEVSPACES_JOBS_VERSION ]]; then 
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"$DISABLE_DEVSPACES_JOBS_VERSION\"][\"disabled\"]|select(.==false))" 'true'
    fi
}

updateDevfileRegistry() {
    REG_ROOT="${WORKDIR}/dependencies/che-devfile-registry"
    SCRIPT_DIR="${REG_ROOT}/build/scripts"
    YAML_ROOT="${REG_ROOT}/devfiles"
    TEMPLATE_FILE="${REG_ROOT}/deploy/openshift/devspaces-devfile-registry.yaml"

    # replace DEVSPACES devfiles with image references to current version tag
    for devfile in $("$SCRIPT_DIR"/list_yaml.sh "$YAML_ROOT"); do
       sed -E -e "s|(.*image: *?.*registry.redhat.io/devspaces/.*:).+|\1${DEVSPACES_VERSION}|g" \
           -i "${devfile}"
    done

    "${SCRIPT_DIR}/update_template.sh" -rn devfile -s "${TEMPLATE_FILE}" -t "${DEVSPACES_VERSION}"
    git diff -q "${YAML_ROOT}" "${TEMPLATE_FILE}" || true
}

# '.parameters[]|select(.name=="IMAGE_TAG")|.value'
updatePluginRegistry() {
    REG_ROOT="${WORKDIR}/dependencies/che-plugin-registry"
    SCRIPT_DIR="${REG_ROOT}/build/scripts"
    YAML_ROOT="${REG_ROOT}"
    TEMPLATE_FILE="${REG_ROOT}/deploy/openshift/devspaces-plugin-registry.yaml"
    for yaml in $("$SCRIPT_DIR"/list_che_yaml.sh "$YAML_ROOT"); do
        sed -r \
            -e "s#(.*image: (['\"]*)(registry.redhat.io|quay.io)/devspaces/.*:)[0-9.]+(['\"]*)#\1${DEVSPACES_VERSION}\2#g" \
            -e "s#quay.io/devspaces/#registry.redhat.io/devspaces/#g" \
            -i "${yaml}"
    done

    # update '.parameters[]|select(.name=="IMAGE_TAG")|.value' ==> 3.yy
    yq -ryiY "(.parameters[] | select(.name == \"IMAGE_TAG\") | .value ) = \"${DEVSPACES_VERSION}\"" "${TEMPLATE_FILE}"
    echo "${COPYRIGHT}$(cat "${TEMPLATE_FILE}")" > "${TEMPLATE_FILE}".2; mv "${TEMPLATE_FILE}".2 "${TEMPLATE_FILE}"

    git diff -q "${YAML_ROOT}" "${TEMPLATE_FILE}" || true
}

commitChanges() {
    if [[ ${docommit} -eq 1 ]]; then
        if [[ $DISABLE_DEVSPACES_JOBS_VERSION ]]; then 
          COMMIT_MSG="${COMMIT_MSG}; disable $DISABLE_DEVSPACES_JOBS_VERSION jobs"
        fi
        if [[ $DISABLE_DEVSPACES_MGMTJOBS_VERSION ]]; then 
          COMMIT_MSG="${COMMIT_MSG}; disable $DISABLE_DEVSPACES_MGMTJOBS_VERSION mgmt jobs"
        fi
        if [[ $ENABLE_DEVSPACES_JOBS_VERSION ]]; then 
          COMMIT_MSG="${COMMIT_MSG}; enable $ENABLE_DEVSPACES_JOBS_VERSION jobs"
        fi
        if [[ $ENABLE_DEVSPACES_MGMTJOBS_VERSION ]]; then 
          COMMIT_MSG="${COMMIT_MSG}; enable $ENABLE_DEVSPACES_MGMTJOBS_VERSION mgmt jobs"
        fi
        if [[ $REMOVE_DEVSPACES_VERSION ]]; then 
          COMMIT_MSG="${COMMIT_MSG}; remove $REMOVE_DEVSPACES_VERSION jobs"
        fi
        git commit -a -s -m "${COMMIT_MSG}"
        git pull origin "${BRANCH}"
        if [[ ${dopush} -eq 1 ]]; then
            PUSH_TRY="$(git push origin "${BRANCH}" 2>&1 || git push origin "${PR_BRANCH}" || true)"
            # shellcheck disable=SC2181
            if [[ $? -gt 0 ]] || [[ $PUSH_TRY == *"protected branch hook declined"* ]]; then
                # if cannot push directly, create pull request for ${BRANCH}
                git branch "${PR_BRANCH}" || true
                git checkout "${PR_BRANCH}" || true
                git pull origin "${PR_BRANCH}" || true
                git push origin "${PR_BRANCH}"
                lastCommitComment="$(git log -1 --pretty=%B)"
                if [[ $(/usr/local/bin/hub version 2>/dev/null || true) ]] || [[ $(which hub 2>/dev/null || true) ]]; then
                    # collect additional commits in the same PR if it already exists
                    { hub pull-request -f -m "${lastCommitComment}

${lastCommitComment}" -b "${BRANCH}" -h "${PR_BRANCH}" "${OPENBROWSERFLAG}"; } || { git merge ${BRANCH}; git push origin "${PR_BRANCH}"; }
                else
                    echo "# Warning: hub is required to generate pull requests. See https://hub.github.com/ to install it."
                    echo -n "# To manually create a pull request, go here: "
                    git config --get remote.origin.url | sed -r -e "s#:#/#" -e "s#git@#https://#" -e "s#\.git#/tree/${PR_BRANCH}/#"
                fi
            fi
        fi
    fi
}

if [[ -z ${DEVSPACES_VERSION} ]]; then
    usage
    exit 1
fi

updateVersion
updatePluginRegistry
updateDevfileRegistry
commitChanges

echo "
VERSION job-config.json, and registries updated.

Remember to run job-configurator to regenerate jobs:
https://main-jenkins-csb-crwqe.apps.ocp-c1.prod.psi.redhat.com/job/job-configurator/buildWithParameters?FAIL_ON_CASC_CHANGES=false&JOBDSL_INCLUDE=.*
https://main-jenkins-csb-crwqe.apps.ocp-c1.prod.psi.redhat.com/job/job-configurator/lastBuild/parameters/
https://main-jenkins-csb-crwqe.apps.ocp-c1.prod.psi.redhat.com/job/job-configurator/lastBuild/console
"
