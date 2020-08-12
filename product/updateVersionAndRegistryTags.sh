#!/bin/bash
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

usage () {
	echo "Usage:   $0 -b [BRANCH] -t [CRW TAG VERSION] [-w WORKDIR]"
	echo "Example: $0 -b crw-2.4-rhel-8 -t 2.4 -w $(pwd)"
	echo "Options: 
	--no-commit, -n    do not commit to BRANCH
	--no-push, -p      do not push to BRANCH
	-prb               set a PR_BRANCH; default: pr-update-version-and-registry-tags-(timestamp)
	-o                 open browser if PR generated
	--help, -h         help
	"
}

if [[ $# -lt 1 ]]; then usage; exit; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-w') WORKDIR="$2"; shift 1;;
    '-b') BRANCH="$2"; shift 1;;
    '-t') CRW_VERSION="$2"; shift 1;;
    '-n'|'--no-commit') docommit=0; dopush=0; shift 0;;
    '-p'|'--no-push') dopush=0; shift 0;;
    '-prb') PR_BRANCH="$2"; shift 1;;
    '-o') OPENBROWSERFLAG="-o"; shift 0;;
    '--help'|'-h') usage; exit;;
    *) OTHER="${OTHER} $1"; shift 0;; 
  esac
  shift 1
done

updateVersion() {
    echo "${CRW_VERSION}" > ${WORKDIR}/dependencies/VERSION
}

updateDevfileRegistry() {
    SCRIPT_DIR="${WORKDIR}/dependencies/che-devfile-registry/build/scripts"
    YAML_ROOT="${WORKDIR}/dependencies/che-devfile-registry/devfiles"

    readarray -d '' devfiles < <("$SCRIPT_DIR"/list_yaml.sh "$YAML_ROOT" | tr '\n' '\0')
    # replace CRW devfiles with image references to current version tag
    sed -E -i "s|(.*image: *?.*registry.redhat.io/codeready-workspaces/.*:).+|\1${CRW_VERSION}|g" ${devfiles[@]}
}

updatePluginRegistry() {
    SCRIPT_DIR="${WORKDIR}/dependencies/che-plugin-registry/build/scripts"
    YAML_ROOT="${WORKDIR}/dependencies/che-plugin-registry/v3/plugins"

    readarray -d '' plugins < <("$SCRIPT_DIR"/list_yaml.sh "$YAML_ROOT" | tr '\n' '\0')
    declare -a latestPlugins
    for plugin in ${plugins[@]}
    do
        #select only latest plugins
        var1=${plugin%/*}
        var2=${var1%/*}
        latestVersion=$(cat "$var2/latest.txt")
        latestPlugin="$var2/$latestVersion/meta.yaml" 
        if [ "$plugin" == "$latestPlugin" ];then
            latestPlugins+=($plugin)
        fi
    done        
    # replace latest CRW plugins with current version tag
    sed -E -i "s|(.*image: *?.*registry.redhat.io/codeready-workspaces/.*:).+|\1${CRW_VERSION}\"|g" ${latestPlugins[@]}
}

commitChanges() {
    if [[ ${docommit} -eq 1 ]]; then 
        git commit -a -s -m "chore(tags) update VERSION and registry references to :${CRW_VERSION}" 
        git pull origin "${BRANCH}"
        if [[ ${dopush} -eq 1 ]]; then
            PUSH_TRY="$(git push origin "${BRANCH}" 2>&1 || git push origin "${PR_BRANCH}" || true)"
            # shellcheck disable=SC2181
            if [[ $? -gt 0 ]] || [[ $PUSH_TRY == *"protected branch hook declined"* ]]; then
                # create pull request for master branch, as branch is restricted
                git branch "${PR_BRANCH}" || true
                git checkout "${PR_BRANCH}" || true
                git pull origin "${PR_BRANCH}" || true
                git push origin "${PR_BRANCH}"
                lastCommitComment="$(git log -1 --pretty=%B)"
                if [[ $(/usr/local/bin/hub version 2>/dev/null || true) ]] || [[ $(which hub 2>/dev/null || true) ]]; then
                    # collect additional commits in the same PR if it already exists 
                    { hub pull-request -f -m "${lastCommitComment}

${lastCommitComment}" -b "${BRANCH}" -h "${PR_BRANCH}" "${OPENBROWSERFLAG}"; } || { git merge master; git push origin "${PR_BRANCH}"; }
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
