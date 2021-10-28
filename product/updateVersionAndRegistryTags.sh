#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# set newer version across the CRW repository in dependencies/VERSION file and registry image tags

PR_BRANCH="pr-update-version-and-registry-tags-$(date +%s)"
OPENBROWSERFLAG="" # if a PR is generated, open it in a browser
docommit=1 # by default DO commit the change
dopush=1 # by default DO push the change
WORKDIR="$(pwd)"
REMOVE_CRW_VERSION=""
ENABLE_CRW_JOBS_VERSION=""
ENABLE_CRW_MGMTJOBS_VERSION=""
DISABLE_CRW_JOBS_VERSION=""
DISABLE_CRW_MGMTJOBS_VERSION=""
BRANCH="crw-2-rhel-8"

usage () {
  echo "
Usage:   $0 -v [CRW CSV_VERSION]
Example: $0 -v 2.y.0

Options:
  --help, -h              help
  -w WORKDIR              work in a differnt dir than $(pwd)
  -b BRANCH               commit to a different branch than $BRANCH
  -t CRW_VERSION          use a specific tag; by default, compute from CSV_VERSION
  --no-commit, -n         do not commit to BRANCH
  --no-push, -p           do not push to BRANCH
  -prb                    set a PR_BRANCH; default: pr-update-version-and-registry-tags-(timestamp)
  -o                      open browser if PR generated
  
  --remove [CRW_VERSION]                  remove data for [CRW_VERSION] (Example: for .Version = 2.yy, delete 2.yy-2)
  --enable-jobs [CRW_VERSION]             enable [CRW_VERSION] jobs in job-config.json, but leave metadata/bundle + management jobs alone
  --enable-management-jobs [CRW_VERSION]  enable ALL [CRW_VERSION] jobs in job-config.json
  --disable-jobs [CRW_VERSION]            disable [CRW_VERSION] jobs in job-config.json, but leave metadata/bundle + management jobs alone
  --disable-management-jobs [CRW_VERSION] disable ALL [CRW_VERSION] jobs in job-config.json (implement code freeze)
  "
}

if [[ $# -lt 1 ]]; then usage; exit; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-w') WORKDIR="$2"; shift 1;;
    '-b') BRANCH="$2"; shift 1;;
    '-v') CSV_VERSION="$2"; shift 1;; # 2.y.0
    '-t') CRW_VERSION="$2"; shift 1;; # 2.y
    '-n'|'--no-commit') docommit=0; dopush=0; shift 0;;
    '-p'|'--no-push') dopush=0; shift 0;;
    '-prb') PR_BRANCH="$2"; shift 1;;
    '-o') OPENBROWSERFLAG="-o"; shift 0;;
    '--remove') REMOVE_CRW_VERSION="$2"; shift 1;;
    '--enable-jobs') ENABLE_CRW_JOBS_VERSION="$2"; shift 1;;
    '--enable-management-jobs') ENABLE_CRW_MGMTJOBS_VERSION="$2"; shift 1;;
    '--disable-jobs') DISABLE_CRW_JOBS_VERSION="$2"; shift 1;;
    '--disable-management-jobs') DISABLE_CRW_MGMTJOBS_VERSION="$2"; shift 1;;
    '--help'|'-h') usage; exit;;
    *) OTHER="${OTHER} $1"; shift 0;;
  esac
  shift 1
done

if [[ ! ${CRW_VERSION} ]]; then
  CRW_VERSION=${CSV_VERSION%.*} # given 2.y.0, want 2.y
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

# update job-config file to product version (x.y)
updateVersion() {
    # deprecated, @since 2.11
    echo "${CRW_VERSION}" > "${WORKDIR}/dependencies/VERSION"
    # @since 2.11
    replaceField "${WORKDIR}/dependencies/job-config.json" '.Version' "${CRW_VERSION}"
    replaceField "${WORKDIR}/dependencies/job-config.json" '.Copyright' "[\"${COPYRIGHT}\"]"

    CRW_Y_VALUE="${CRW_VERSION#*.}"
    UPPER_CHE_Y=$(( (${CRW_Y_VALUE} + 6) * 2 ))
    LOWER_CHE_Y=$(( ((${CRW_Y_VALUE} + 6) * 2) - 1 ))
    
    # CRW-2155, if version is in the json update it for che and crw branches
    # otherwise inject new version.
    check=$(cat ${WORKDIR}/dependencies/job-config.json | jq '.Jobs[] | keys' | grep "\"${CRW_VERSION}\"")
    if [[ ${check} ]]; then #just updating
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${CRW_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"main\"))" "[\"7.${UPPER_CHE_Y}.x\",\"7.${LOWER_CHE_Y}.x\"]"
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${CRW_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"crw-2-rhel-8\"))" "[\"crw-${CRW_VERSION}-rhel-8\",\"crw-${CRW_VERSION}-rhel-8\"]"

      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${CRW_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"main\"))" "[\"7.${UPPER_CHE_Y}.x\",\"7.${LOWER_CHE_Y}.x\"]"
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${CRW_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"crw-2-rhel-8\"))" "[\"crw-${CRW_VERSION}-rhel-8\",\"crw-${CRW_VERSION}-rhel-8\"]"

      #make sure jobs are enabled
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${CRW_VERSION}\"][\"disabled\"]|select(.==true))" 'false'
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${CRW_VERSION}\"][\"disabled\"]|select(.==true))" 'false'
      #remove version if desired
      if [[ $REMOVE_CRW_VERSION ]]; then
        replaceField "${WORKDIR}/dependencies/job-config.json" "." "del(..|.[\"${REMOVE_CRW_VERSION}\"]?)"
      fi
    else
      # Get top level keys to start (Jobs, CSVs, Other, etc)
      TOP_KEYS=($(cat ${WORKDIR}/dependencies/job-config.json | jq -r 'keys[]'))

      for TOP_KEY in ${TOP_KEYS[@]}
      do
        if [[ (${TOP_KEY} != "Version") && (${TOP_KEY} != "Copyright") && (${TOP_KEY} != "Purpose") ]]; then
          # Get the sub-keys in Jobs so we can add a new object
          KEYS=($(cat ${WORKDIR}/dependencies/job-config.json | jq -r ".\"${TOP_KEY}\" | keys[]"))

          for KEY in ${KEYS[@]}
          do
            #save content of 2.x
            content=$(cat ${WORKDIR}/dependencies/job-config.json | jq ".\"${TOP_KEY}\"[\"${KEY}\"][\"2.x\"]")
            #Add CRW_VERSION from 2.x then delete 2.x
            #then append 2.x so the general order remains the same
            replaceField "${WORKDIR}/dependencies/job-config.json" ".\"${TOP_KEY}\"[\"${KEY}\"]" "(. + {\"${CRW_VERSION}\": .\"2.x\"} | del(.\"2.x\"))"
            replaceField "${WORKDIR}/dependencies/job-config.json" ".\"${TOP_KEY}\"[\"${KEY}\"]" ". + {\"2.x\": ${content}}"

            #while in here remove version if desired
            if [[ $REMOVE_CRW_VERSION ]]; then
              replaceField "${WORKDIR}/dependencies/job-config.json" ".\"${TOP_KEY}\"[\"${KEY}\"]" "del(.\"${REMOVE_CRW_VERSION}\")"
            fi
          done
        fi
      done

      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${CRW_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"main\"))" "[\"7.${UPPER_CHE_Y}.x\",\"7.${LOWER_CHE_Y}.x\"]"
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${CRW_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"crw-2-rhel-8\"))" "[\"crw-${CRW_VERSION}-rhel-8\",\"crw-${CRW_VERSION}-rhel-8\"]"

      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${CRW_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"main\"))" "[\"7.${UPPER_CHE_Y}.x\",\"7.${LOWER_CHE_Y}.x\"]"
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${CRW_VERSION}\"][\"upstream_branch\"]|select(.[]?==\"crw-2-rhel-8\"))" "[\"crw-${CRW_VERSION}-rhel-8\",\"crw-${CRW_VERSION}-rhel-8\"]"

      #make sure new builds are enabled
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${CRW_VERSION}\"][\"disabled\"]|select(.==true))" 'false'
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${CRW_VERSION}\"][\"disabled\"]|select(.==true))" 'false'

      #find and disable version-2
      #start by gathering all CRW_VERSIONs that have data in the json
      VERSION_KEYS=($(cat ${WORKDIR}/dependencies/job-config.json | jq -r '.Jobs'[\"dashboard\"]' | keys[]'))
      #get the array index of version -2. length -1 is 2.x, -2 is the version that was added, so the old version that needs to get disabled is length - 4
      DISABLE_VERSION_INDEX=$(( ${#VERSION_KEYS[@]} - 4 )) 

      #Disable version -2, and everything previous (if there)
      while [[ $DISABLE_VERSION_INDEX -gt -1 ]]; do
         replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${VERSION_KEYS[$DISABLE_VERSION_INDEX]}\"][\"disabled\"]|select(.==false))" 'true'
         replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${VERSION_KEYS[$DISABLE_VERSION_INDEX]}\"][\"disabled\"]|select(.==false))" 'true'
         DISABLE_VERSION_INDEX=$(( $DISABLE_VERSION_INDEX -1 ))
      done

      #update tags
      replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"FLOATING_QUAY_TAGS\"][\"${CRW_VERSION}\"]" "\"next\""
      replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"FLOATING_QUAY_TAGS\"][\"2.x\"]" "\"next\""

      #the 'latest' tag should go on the prevuous/stable version, which would be version -1, or the index 3 form the end of the VERSION_KEYS array
      LATEST_INDEX=$(( ${#VERSION_KEYS[@]} - 3 )) 
      replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"FLOATING_QUAY_TAGS\"][\"${VERSION_KEYS[$LATEST_INDEX]}\"]" "\"latest\""
      #set the previous 'latest' to be its own version
      replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"FLOATING_QUAY_TAGS\"][\"${VERSION_KEYS[$DISABLE_VERSION_INDEX]}\"]" "\"${VERSION_KEYS[$DISABLE_VERSION_INDEX]}\""
    fi 

    # optionally, can enable/disable specific job sets for a given version
    if [[ $ENABLE_CRW_MGMTJOBS_VERSION ]]; then 
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"$ENABLE_CRW_MGMTJOBS_VERSION\"][\"disabled\"]|select(.==true))" 'false'
    fi
    if [[ $ENABLE_CRW_JOBS_VERSION ]]; then 
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"$ENABLE_CRW_JOBS_VERSION\"][\"disabled\"]|select(.==true))" 'false'
    fi
    if [[ $DISABLE_CRW_MGMTJOBS_VERSION ]]; then 
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"$DISABLE_CRW_MGMTJOBS_VERSION\"][\"disabled\"]|select(.==false))" 'true'
    fi
    if [[ $DISABLE_CRW_JOBS_VERSION ]]; then 
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"$DISABLE_CRW_JOBS_VERSION\"][\"disabled\"]|select(.==false))" 'true'
    fi
}

updateDevfileRegistry() {
    REG_ROOT="${WORKDIR}/dependencies/che-devfile-registry"
    SCRIPT_DIR="${REG_ROOT}/build/scripts"
    YAML_ROOT="${REG_ROOT}/devfiles"
    TEMPLATE_FILE="${REG_ROOT}/deploy/openshift/crw-devfile-registry.yaml"

    # replace CRW devfiles with image references to current version tag
    for devfile in $("$SCRIPT_DIR"/list_yaml.sh "$YAML_ROOT"); do
       sed -E -e "s|(.*image: *?.*registry.redhat.io/codeready-workspaces/.*:).+|\1${CRW_VERSION}|g" \
           -i "${devfile}"
    done

    "${SCRIPT_DIR}/update_template.sh" -rn devfile -s "${TEMPLATE_FILE}" -t "${CRW_VERSION}"
    git diff -q "${YAML_ROOT}" "${TEMPLATE_FILE}" || true
}

# '.parameters[]|select(.name=="IMAGE_TAG")|.value'
updatePluginRegistry() {
    REG_ROOT="${WORKDIR}/dependencies/che-plugin-registry"
    SCRIPT_DIR="${REG_ROOT}/build/scripts"
    YAML_ROOT="${REG_ROOT}"
    TEMPLATE_FILE="${REG_ROOT}/deploy/openshift/crw-plugin-registry.yaml"

    for yaml in $("$SCRIPT_DIR"/list_che_yaml.sh "$YAML_ROOT"); do
        sed -E \
            -e "s|(.*image: (['\"]*)registry.redhat.io/codeready-workspaces/.*:)[0-9.]+(['\"]*)|\1${CRW_VERSION}\2|g" \
            -i "${yaml}"
    done

    # update '.parameters[]|select(.name=="IMAGE_TAG")|.value' ==> 2.yy
    yq -ryiY "(.parameters[] | select(.name == \"IMAGE_TAG\") | .value ) = \"${CRW_VERSION}\"" "${TEMPLATE_FILE}"
    echo "${COPYRIGHT}$(cat "${TEMPLATE_FILE}")" > "${TEMPLATE_FILE}".2; mv "${TEMPLATE_FILE}".2 "${TEMPLATE_FILE}"

    git diff -q "${YAML_ROOT}" "${TEMPLATE_FILE}" || true
}

COMMIT_MSG="chore(tags) update VERSION and registry references to :${CRW_VERSION}"
if [[ $DISABLE_CRW_JOBS_VERSION ]]; then 
  COMMIT_MSG="${COMMIT_MSG}; disable $DISABLE_CRW_JOBS_VERSION jobs"
fi
if [[ $DISABLE_CRW_MGMTJOBS_VERSION ]]; then 
  COMMIT_MSG="${COMMIT_MSG}; disable $DISABLE_CRW_MGMTJOBS_VERSION mgmt jobs"
fi
if [[ $ENABLE_CRW_JOBS_VERSION ]]; then 
  COMMIT_MSG="${COMMIT_MSG}; enable $ENABLE_CRW_JOBS_VERSION jobs"
fi
if [[ $ENABLE_CRW_MGMTJOBS_VERSION ]]; then 
  COMMIT_MSG="${COMMIT_MSG}; enable $ENABLE_CRW_MGMTJOBS_VERSION mgmt jobs"
fi
if [[ $REMOVE_CRW_VERSION ]]; then 
  COMMIT_MSG="${COMMIT_MSG}; remove $REMOVE_CRW_VERSION jobs"
fi

commitChanges() {
    if [[ ${docommit} -eq 1 ]]; then
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

if [[ -z ${CRW_VERSION} ]]; then
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
https://main-jenkins-csb-crwqe.apps.ocp4.prod.psi.redhat.com/job/job-configurator/buildWithParameters?FAIL_ON_CASC_CHANGES=false&JOBDSL_INCLUDE=.*CRW_CI.*
https://main-jenkins-csb-crwqe.apps.ocp4.prod.psi.redhat.com/job/job-configurator/lastBuild/parameters/
https://main-jenkins-csb-crwqe.apps.ocp4.prod.psi.redhat.com/job/job-configurator/lastBuild/console
"
