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
REMOVE_BRANCH=""

usage () {
	echo "Usage:   $0 -b [BRANCH] -v [CRW CSV VERSION] -t [CRW TAG VERSION] [-w WORKDIR]"
	echo "Example: $0 -b crw-2-rhel-8 -v 2.y+1.0 -t 2.y+1 -w $(pwd)"
	echo "Options:
	--no-commit, -n    do not commit to BRANCH
	--no-push, -p      do not push to BRANCH
	-prb               set a PR_BRANCH; default: pr-update-version-and-registry-tags-(timestamp)
	-o                 open browser if PR generated
  -u [CRW VERSION]   remove data for [CRW VERSION] from job-config.json
	--help, -h         help
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
    '-u') REMOVE_BRANCH="$2"; shift 1;;
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

    CRW_Y_VALUE="${crwVersion#*.}"
    UPPER_CHE=$(( (${CRW_Y_VALUE} + 6) * 2 ))
    LOWER_CHE=$(( ((${CRW_Y_VALUE} + 6) * 2) - 1 ))
    
    # CRW-2155, if version is in the json update it for che and crw branches
    # otherwise inject new version.
    check=$(cat ${WORKDIR}/dependencies/job-config.json | jq '.Jobs[] | keys' | grep "\"${CRW_VERSION}\"")
    if [[ ${check} ]]; then #just updating
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${crwVersion}\"]|select(.[]?==\"main\"))" "[\"7.${UPPER_CHE}.x\",\"7.${LOWER_CHE}.x\"]"
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${crwVersion}\"]|select(.[]?==\"crw-2-rhel-8\"))" "[\"${BRANCH}\",\"${BRANCH}\"]"
      #make sure jobs are enabled
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${CRW_VERSION}\"][\"disabled\"]|select(.==true))" 'false'
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${CRW_VERSION}\"][\"disabled\"]|select(.==true))" 'false'
    else
      # Get top level keys to start (Jobs, CSVs, Other, etc)
      TOP_KEYS=$(cat ${WORKDIR}/dependencies/job-config.json | jq 'keys')
      TOP_KEYS=$(echo ${TOP_KEYS} | sed -e 's/\[//' -e 's/\]//' -e 's/\ //' -e 's/\,//g') #clean for array
      TOP_KEYS=(${TOP_KEYS})

      TOP_LENGTH=${#TOP_KEYS[@]}
      for (( i=0; i<${TOP_LENGTH}; i++ ))
      do
        if [[ (${TOP_KEYS[i]} != "\"Version\"") && (${TOP_KEYS[i]} != "\"Copyright\"") && (${TOP_KEYS[i]} != "\"Purpose\"") ]]; then
          # Get the sub-keys in Jobs so we can add a new object
          KEYS=$(cat ${WORKDIR}/dependencies/job-config.json | jq '.'${TOP_KEYS[i]}' | keys')
          KEYS=$(echo ${KEYS} | sed -e 's/\[//' -e 's/\]//' -e 's/\ //' -e 's/\,//g')
          KEYS=(${KEYS})

          KEYS_LENGTH=${#KEYS[@]}
          for (( j=0; j<${KEYS_LENGTH}; j++ ))
          do
            #save content of 2.x
            content=$(cat ${WORKDIR}/dependencies/job-config.json | jq ".${TOP_KEYS[i]}[${KEYS[j]}][\"2.x\"]")
            #Add CRW_VERSION from 2.x then delete 2.x
            #then append 2.x so the general order remains the same
            replaceField "${WORKDIR}/dependencies/job-config.json" ".${TOP_KEYS[i]}[${KEYS[j]}]" "(. + {\"${CRW_VERSION}\": .\"2.x\"} | del(.\"2.x\"))"
            replaceField "${WORKDIR}/dependencies/job-config.json" ".${TOP_KEYS[i]}[${KEYS[j]}]" ". + {\"2.x\": ${content}}"

            #while in here remove version if desired
            if [[ $REMOVE_BRANCH ]]; then
              replaceField "${WORKDIR}/dependencies/job-config.json" ".${TOP_KEYS[i]}[${KEYS[j]}]" "del(.\"${REMOVE_BRANCH}\")"
            fi
          done
        fi
      done

      #if che branches exist then update to those instead of main; check against https://github.com/eclipse-che/che-dashboard
      UPPER_CHE_CHECK=$(git ls-remote --heads https://github.com/eclipse-che/che-dashboard.git ${UPPER_CHE})
      LOWER_CHE_CHECK=$(git ls-remote --heads https://github.com/eclipse-che/che-dashboard.git ${LOWER_CHE})

      if [ $UPPER_CHE_CHECK ] || [ $LOWER_CHE_CHECK ]; then
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${crwVersion}\"]|select(.[]?==\"main\"))" "[\"7.${UPPER_CHE}.x\",\"7.${LOWER_CHE}.x\"]"
      fi

      #if crw-2.yy exists use that
      CRW_CHECK=$(git ls-remote --heads https://github.com/redhat-developer/codeready-workspaces.git ${BRANCH})
      if [[ $CRW_CHECK ]]; then
        replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${crwVersion}\"]|select(.[]?==\"crw-2-rhel-8\"))" "[\"${BRANCH}\",\"${BRANCH}\"]"
      fi

      #make sure new builds are enabled
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][\"${CRW_VERSION}\"][\"disabled\"]|select(.==true))" 'false'
      replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][\"${CRW_VERSION}\"][\"disabled\"]|select(.==true))" 'false'

      #find and disable version-2
      VERSION_KEYS=$(cat ${WORKDIR}/dependencies/job-config.json | jq '.Jobs'[\"dashboard\"]' | keys') #use dashboard as baseline since they should all be the same.
      VERSION_KEYS=$(echo ${VERSION_KEYS} | sed -e 's/\[//' -e 's/\]//' -e 's/\ //' -e 's/\,//g')
      VERSION_KEYS=($VERSION_KEYS)
      OLD_VERSION=$(( ${#VERSION_KEYS[@]} - 4 )) 

      if [[ ${VERSION_KEYS[$OLD_VERSION]} ]]; then
         replaceField "${WORKDIR}/dependencies/job-config.json" "(.Jobs[][${VERSION_KEYS[$OLD_VERSION]}][\"disabled\"]|select(.==false))" 'true'
         replaceField "${WORKDIR}/dependencies/job-config.json" "(.\"Management-Jobs\"[][${VERSION_KEYS[$OLD_VERSION]}][\"disabled\"]|select(.==false))" 'true'
      fi

      #update tags
      replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"FLOATING_QUAY_TAGS\"][\"${CRW_VERSION}\"]" "\"next\""

      VERSION_LATEST=$(( ${#VERSION_KEYS[@]} - 3 )) 
      replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"FLOATING_QUAY_TAGS\"][${VERSION_KEYS[$VERSION_LATEST]}]" "\"latest\""
      replaceField "${WORKDIR}/dependencies/job-config.json" ".Other[\"FLOATING_QUAY_TAGS\"][${VERSION_KEYS[$OLD_VERSION]}]" ${VERSION_KEYS[$OLD_VERSION]}

    fi 

    #remove unwanted version, if any0
    if [[ $REMOVE_BRANCH ]]; then
      TOP_KEYS=$(cat ${WORKDIR}/dependencies/job-config.json | jq 'keys')
      TOP_KEYS=$(echo ${TOP_KEYS} | sed -e 's/\[//' -e 's/\]//' -e 's/\ //' -e 's/\,//g') #clean for array
      TOP_KEYS=(${TOP_KEYS})

      TOP_LENGTH=${#TOP_KEYS[@]}
      for (( i=0; i<${TOP_LENGTH}; i++ ))
      do
        if [[ (${TOP_KEYS[i]} != "\"Version\"") && (${TOP_KEYS[i]} != "\"Copyright\"") && (${TOP_KEYS[i]} != "\"Purpose\"") ]]; then
          # Get the sub-keys
          KEYS=$(cat ${WORKDIR}/dependencies/job-config.json | jq '.'${TOP_KEYS[i]}' | keys')
          KEYS=$(echo ${KEYS} | sed -e 's/\[//' -e 's/\]//' -e 's/\ //' -e 's/\,//g')
          KEYS=(${KEYS})

          KEYS_LENGTH=${#KEYS[@]}
          for (( j=0; j<${KEYS_LENGTH}; j++ ))
          do
            replaceField "${WORKDIR}/dependencies/job-config.json" ".${TOP_KEYS[i]}[${KEYS[j]}]" "del(.\"${REMOVE_BRANCH}\")"
          done
        fi
      done
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

commitChanges() {
    if [[ ${docommit} -eq 1 ]]; then
        git commit -a -s -m "chore(tags) update VERSION and registry references to :${CRW_VERSION}"
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
