#!/bin/bash
#
# Copyright (c) 2021-2023 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# Update versions and upstream branches in dependencies/job-config.json and across the DEVSPACES repository
WORKDIR="$(pwd)"
JOB_CONFIG="${WORKDIR}/dependencies/job-config.json"
CHE_OFFSET=58 # DS 3.12 => (12 * 2) + 58 = 82 ==> Che 7.82
DWO_OFFSET=14 # DS 3.12 => DWO 0.26
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
doupdateversion=1 #by default update the VERSION files
BRANCH="devspaces-3-rhel-8"
PR_BRANCH="pr-update-version-and-registry-tags-$(date +%s)"
OPENBROWSERFLAG="" # if a PR is generated, open it in a browser
docommit=1 # by default DO commit the change
dopush=1 # by default DO push the change

usage() {
  echo "
Usage:  $0 -t DEVSPACES_VERSION

Options:
  --help, -h                                help
  -t DEVSPACES_VERSION                      3.yy DevSpaces version to be added or updated
  -b BRANCH                                 commit to a different branch than $BRANCH
  -w WORKDIR                                work in a different dir than $(pwd), should be the devspaces git directory
  -v                                        verbose, enables basic debug statements to let you know if you're in the right loops
  --no-version, -nv                         don't run the version updates, just update job-config values (updating a previous release etc)
  --remove [DEVSPACES_VERSION]              remove data for [DEVSPACES_VERSION] (Example: for .Version = 3.yy, delete 3.yy-3)
  --enable-jobs [DEVSPACES_VERSION]         enable [DEVSPACES_VERSION] jobs in job-config.json
  --disable-jobs [DEVSPACES_VERSION]        disable [DEVSPACES_VERSION] jobs in job-config.json
  --no-commit, -n                           do not commit or push to BRANCH
  --no-push, -p                             do not push to BRANCH
  -prb                                      set a PR_BRANCH; default: pr-update-version-and-registry-tags-(timestamp)
  -o                                        open browser if PR generated
"
}

if [[ $# -lt 1 ]]; then usage; exit; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '--help'|'-h') usage; exit;;
    '-t') DEVSPACES_VERSION="$2"; shift 1;; # 3.yy
    '-b') BRANCH="$2"; shift 1;;
    '-w') WORKDIR="$2"; shift 1;;
    '-v') VERBOSE=1; shift 0;;
    '-nv'|'--no-version') doupdateversion=0; shift 0;;
    '--remove') REMOVE_DEVSPACES_VERSION="$2"; shift 1;;
    '--enable-jobs') ENABLE_JOBS_VERSION="$2"; shift 1;;
    '--disable-jobs') DISABLE_JOBS_VERSION="$2"; shift 1;;
    '-n'|'--no-commit') docommit=0; dopush=0; shift 0;;
    '-p'|'--no-push') dopush=0; shift 0;;
    '-prb') PR_BRANCH="$2"; shift 1;;
    '-o') OPENBROWSERFLAG="-o"; shift 0;;
    *) OTHER="${OTHER} $1"; shift 0;;
  esac
  shift 1
done

if [[ -z ${DEVSPACES_VERSION} ]]; then
    usage
    exit 1
fi

##################################################
# Common functions
##################################################
replaceField() {
  theFile="$1"
  updateName="$2"
  updateVal="$3"

  if [[ ${theFile} == *".json" ]]; then
    changed=$(cat "${theFile}" | jq ${updateName}' |= '"$updateVal")
    echo "${changed}" > "${theFile}"
  elif [[ ${theFile} == *".yml" ]] || [[ ${theFile} == *".yaml" ]]; then
    changed=$(cat "${theFile}" | yq --arg updateName "${updateName}" --arg updateVal "${updateVal}" ${updateName}' = $updateVal')
    echo "${COPYRIGHT}${changed}" > "${theFile}"
  fi
}

# for a given DEVSPACES version, compute the equivalent Che versions that could be compatible 
computeLatestPackageVersion() {
  found=0
  BASE_VERSION="$1" # Dev Spaces 3.y version to use for computations
  packageName="$2"
  THIS_Y_VALUE="${BASE_VERSION#*.}"; 
  # note that these values are used for versions where main doesn't make sense, such as  @eclipse-che/plugin-registry-generator
  THIS_CHE_Y=$(( (${THIS_Y_VALUE} * 2) + ${CHE_OFFSET} )); 
  THIS_CHE_Y_LOWER=$(( ${THIS_CHE_Y} - 1 ));
  if [[ $VERBOSE ]]; then echo "For THIS_Y_VALUE = $THIS_Y_VALUE, got THIS_CHE_Y = $THIS_CHE_Y and THIS_CHE_Y_LOWER = $THIS_CHE_Y_LOWER"; fi

  # check if .2, .1, .0 version exists in npmjs.com
  for y in $THIS_CHE_Y $THIS_CHE_Y_LOWER; do 
    for z in 2 1 0; do 
      # echo "curl -sSI https://www.npmjs.com/package/${packageName}/v/7.${y}.${z}"
      if [[ $(curl -sSI "https://www.npmjs.com/package/${packageName}/v/7.${y}.${z}" | grep 404) != *"404"* ]]; then
      change="plugin-registry-generator[$BASE_VERSION] = 7.${y}.${z}"
      COMMIT_MSG="${COMMIT_MSG}; update $change"
        echo "Update $change"
        replaceField "${JOB_CONFIG}" ".Other[\"${packageName}\"][\"${BASE_VERSION}\"]" "\"7.${y}.${z}\""
        found=1
        break 2
      fi
    done
  done
  if [[ $found -eq 0 ]]; then
    replaceField "${JOB_CONFIG}" ".Other[\"${packageName}\"][\"${BASE_VERSION}\"]" "\"latest\""
  fi
}

computeLatestCSV() {
  image=$1 # operator-bundle
  SOURCE_CONTAINER=registry.redhat.io/devspaces/devspaces-${image}
  containerTag=$(skopeo inspect docker://${SOURCE_CONTAINER} 2>/dev/null | jq -r '.Labels.url' | sed -r -e "s#.+/images/##")
  echo "Found containerTag = ${containerTag}"

  # extract the CSV version from the container as with CVE respins, the CSV version != the nominal container tag or JIRA version 2.13.1
  #if [[ ! -x ${SCRIPTPATH}/containerExtract.sh ]]; then
  if [[ ! -x ${WORKDIR}/product/containerExtract.sh ]]; then
      curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/devspaces-3-rhel-8/product/containerExtract.sh
      chmod +x containerExtract.sh
  fi
  rm -fr /tmp/${SOURCE_CONTAINER//\//-}-${containerTag}-*/
  #${SCRIPTPATH}/containerExtract.sh ${SOURCE_CONTAINER}:${containerTag} --delete-before --delete-after 2>&1 >/dev/null || true
  ${WORKDIR}/product/containerExtract.sh ${SOURCE_CONTAINER}:${containerTag} --delete-before --delete-after 2>&1 >/dev/null || true
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

##################################################
# Update functions
##################################################
updateVersion() {
  if [[ ${doupdateversion} -eq 1 ]]; then
    # VERSION file is still used by util2.groovy and potentially others.
    echo "${DEVSPACES_VERSION}" > "${WORKDIR}/dependencies/VERSION"
    # Update Version field in job-config.json
    replaceField "${JOB_CONFIG}" '.Version' "\"${DEVSPACES_VERSION}\""

    if [[ $VERBOSE ]]; then echo "[DEBUG] Updating Version files to $DEVSPACES_VERSION"; fi
  fi
}

COMMIT_MSG=""
updateJobConfig() {
  # Update .Copyright in job-config.json
  replaceField "${JOB_CONFIG}" '.Copyright' "[\"${COPYRIGHT}\"]"

  # Update upstream branch mappings
  DEVSPACES_Y_VALUE="${DEVSPACES_VERSION#*.}"
  CHE_Y=$(( (${DEVSPACES_Y_VALUE} * 2 ) + ${CHE_OFFSET} ))
  DWO_Y=$(( ${DEVSPACES_Y_VALUE} + ${DWO_OFFSET} ))

  JOB_KEYS=("Jobs" "Management-Jobs")

  # CRW-2155, if version is in the json update it for che and devspaces branches
  # otherwise inject new version.
  check=$(cat ${JOB_CONFIG} | jq '.Jobs[] | keys' | grep "\"${DEVSPACES_VERSION}\"")
  if [[ ${check} ]]; then # Just updating
    # Only need to change commit message, other actions are universal.
    COMMIT_MSG="ci: update ${DEVSPACES_VERSION}"
    if [[ $VERBOSE ]]; then echo "[DEBUG] Updating $DEVSPACES_VERSION in job-config.json"; fi
  else # Adding
    COMMIT_MSG="ci: add new ${DEVSPACES_VERSION}"
    if [[ $VERBOSE ]]; then echo "[DEBUG] Adding $DEVSPACES_VERSION to job-config.json"; fi

    # Get top level keys to start (Jobs, CSVs, Other, etc)
    TOP_KEYS=($(cat ${JOB_CONFIG} | jq -r 'keys[]'))
    if [[ $VERBOSE ]]; then echo "[DEBUG] TOP_KEYS = ${TOP_KEYS[@]}"; fi

    for TOP_KEY in ${TOP_KEYS[@]}
    do
      if [[ (${TOP_KEY} != "Version") && (${TOP_KEY} != "Copyright") && (${TOP_KEY} != "Purpose") ]]; then
        # Get the sub-keys in Jobs so we can add a new object
        KEYS=($(cat ${JOB_CONFIG} | jq -r ".\"${TOP_KEY}\" | keys[]"))
        if [[ $VERBOSE ]]; then echo "[DEBUG] KEYS = ${KEYS[@]}"; fi

        for KEY in ${KEYS[@]}
        do
          #save content of 3.x
          content=$(cat ${JOB_CONFIG} | jq ".\"${TOP_KEY}\"[\"${KEY}\"][\"3.x\"]")
          if [[ $(echo $content | grep "\"") ]]; then #is there a 3.x version
            #Add DEVSPACES_VERSION from 3.x then delete 3.x
            #then append 3.x so the general order remains the same
            replaceField "${JOB_CONFIG}" ".\"${TOP_KEY}\"[\"${KEY}\"]" "(. + {\"${DEVSPACES_VERSION}\": .\"3.x\"} | del(.\"3.x\"))"
            replaceField "${JOB_CONFIG}" ".\"${TOP_KEY}\"[\"${KEY}\"]" ". + {\"3.x\": ${content}}"
          fi
        done
      fi
    done

    for ver in "${DEVSPACES_VERSION}" "3.x"; do
      replaceField "${JOB_CONFIG}" ".CSVs[\"operator-bundle\"][\"${ver}\"][\"CSV_VERSION\"]" "\"${DEVSPACES_VERSION}.0\""
      # update DWO mapping
      replaceField "${JOB_CONFIG}" ".Other[\"DEV_WORKSPACE_OPERATOR_TAG\"][\"${ver}\"]" "\"0.${DWO_Y}\""
    done
  fi

  if [[ $REMOVE_DEVSPACES_VERSION ]]; then
    if [[ $VERBOSE ]]; then echo "[DEBUG] Removing $REMOVE_DEVSPACES_VERSION"; fi
    replaceField "${JOB_CONFIG}" "." "del(..|.[\"${REMOVE_DEVSPACES_VERSION}\"]?)"
  fi
  
  # Find and version - 2 to disable in loop (should only be needed for hotfix releases)
  VERSION_KEYS=($(cat ${JOB_CONFIG} | jq -r '.Jobs'[\"dashboard\"]' | keys[]')) # Using dashboard to find versions
  #If there are more than 4 versions throw an error until extra versions are weeded out.
  if [[ ${#VERSION_KEYS[@]} -gt 4 ]]; then echo "There are more than 4 versions in the job-config.json, please remove one."; exit 1; fi

  if [[ $VERBOSE ]]; then echo "[DEBUG] Versions in job-config.json: ${VERSION_KEYS[@]}"; fi
  OLDEST="${VERSION_KEYS[0]}"
  LATEST="${VERSION_KEYS[1]}"

  for JOB_KEY in ${JOB_KEYS[@]}
  do
    if [[ $VERBOSE ]]; then echo "[DEBUG] JOB_KEY = $JOB_KEY"; fi
    if [[ $VERBOSE ]]; then echo "[DEBUG] Updating upstream branches."; fi
    replaceField "${JOB_CONFIG}" "(.\"${JOB_KEY}\"[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?|contains(\".x\")))" "[\"7.${CHE_Y}.x\",\"main\"]"
    replaceField "${JOB_CONFIG}" "(.\"${JOB_KEY}\"[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"main\"))" "[\"7.${CHE_Y}.x\",\"main\"]"
    replaceField "${JOB_CONFIG}" "(.\"${JOB_KEY}\"[][\"${DEVSPACES_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"devspaces-3-rhel-8\"))" "[\"devspaces-${DEVSPACES_VERSION}-rhel-8\",\"devspaces-${DEVSPACES_VERSION}-rhel-8\"]"

    if [[ $VERBOSE ]]; then echo "Make sure \"current\" jobs are enabled"; fi
    replaceField "${JOB_CONFIG}" "(.\"${JOB_KEY}\"[][\"${DEVSPACES_VERSION}\"][\"disabled\"]|select(.==true))" 'false'

    if [[ $VERBOSE ]]; then echo "[DEBUG] Disabling $OLDEST"; fi
    replaceField "${JOB_CONFIG}" "(.\"${JOB_KEY}\"[][\"${OLDEST}\"][\"disabled\"]|select(.==false))" 'true'

     # optionally, can enable/disable specific job sets for a given version
    if [[ $ENABLE_JOBS_VERSION ]]; then 
        replaceField "${JOB_CONFIG}" "(.\"${JOB_KEY}\"[][\"$ENABLE_JOBS_VERSION\"][\"disabled\"]|select(.==true))" 'false'
    fi
    if [[ $DISABLE_JOBS_VERSION ]]; then 
        replaceField "${JOB_CONFIG}" "(.\"${JOB_KEY}\"[][\"$DISABLE_JOBS_VERSION\"][\"disabled\"]|select(.==false))" 'true'
    fi

  done

  # set .2 version of @eclipse-che/plugin-registry-generator if currently set to latest
  if [[ $(jq -r ".Other[\"@eclipse-che/plugin-registry-generator\"][\"${OLDEST}\"]" "${JOB_CONFIG}") == "latest" ]]; then
    computeLatestPackageVersion $OLDEST "@eclipse-che/plugin-registry-generator"
  fi
  computeLatestPackageVersion $LATEST "@eclipse-che/plugin-registry-generator"

  # Update Tags
  if [[ $VERBOSE ]]; then 
    echo "[DEBUG] Updating latest/next tags"
    echo "[DEBUG] Setting 3.x and ${VERSION_KEYS[2]} to \"next\""
    echo "[DEBUG] Setting ${LATEST} to \"latest\""
    echo "[DEBUG] Setting ${OLDEST} to \"${OLDEST}\""
  fi
  replaceField "${JOB_CONFIG}" ".Other[\"FLOATING_QUAY_TAGS\"][\"${VERSION_KEYS[2]}\"]" "\"next\""
  replaceField "${JOB_CONFIG}" ".Other[\"FLOATING_QUAY_TAGS\"][\"3.x\"]" "\"next\""
  replaceField "${JOB_CONFIG}" ".Other[\"FLOATING_QUAY_TAGS\"][\"${LATEST}\"]" "\"latest\""
  replaceField "${JOB_CONFIG}" ".Other[\"FLOATING_QUAY_TAGS\"][\"${OLDEST}\"]" "\"${OLDEST}\""

  # update CSV_VERSION_PREV values
  computeLatestCSV operator-bundle
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
            -e "s|# Copyright.*|# Copyright (c) 2018-$(date +%Y) Red Hat, Inc.|g" \
            -i "${yaml}"
    done

    # update '.parameters[]|select(.name=="IMAGE_TAG")|.value' ==> 3.yy
    yq -ri "(.parameters[] | select(.name == \"IMAGE_TAG\") | .value ) = \"${DEVSPACES_VERSION}\"" "${TEMPLATE_FILE}"

    git diff -q "${YAML_ROOT}" "${TEMPLATE_FILE}" || true
}

commitChanges() {
  if [[ ${docommit} -eq 1 ]]; then
    if [[ $DISABLE_JOBS_VERSION ]]; then 
      COMMIT_MSG="${COMMIT_MSG}; disable $DISABLE_JOBS_VERSION jobs"
    fi
    if [[ $ENABLE_JOBS_VERSION ]]; then 
      COMMIT_MSG="${COMMIT_MSG}; enable $ENABLE_JOBS_VERSION jobs"
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

# Run update functions
updateVersion
updateJobConfig
updateDevfileRegistry
updatePluginRegistry
commitChanges

echo "
VERSION job-config.json, and registries updated.

Remember to run job-configurator to regenerate jobs:
https://main-jenkins-csb-crwqe.apps.ocp-c1.prod.psi.redhat.com/job/job-configurator/buildWithParameters?FAIL_ON_CASC_CHANGES=false&JOBDSL_INCLUDE=.*
https://main-jenkins-csb-crwqe.apps.ocp-c1.prod.psi.redhat.com/job/job-configurator/lastBuild/parameters/
https://main-jenkins-csb-crwqe.apps.ocp-c1.prod.psi.redhat.com/job/job-configurator/lastBuild/console
"
