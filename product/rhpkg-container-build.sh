#!/bin/bash -e
# this script is called by jenkins job of a similar name, get-sources-rhpkg-container-build
# 1. run the appropriate version of get-sources*.sh (which fetches or builds dependent binaries, then runs rhpkg container-build)
# 2. collect log information to report on build status

usage () {
  echo "Usage:   $0 JOB_BRANCH -s [SOURCEDIR] [--nobuild] [-l /path/to/log.txt] [-v (verbose)] [--noclean]"
  echo "Example (run build and parse log): $0 2.9 -s /path/to/sources"
  echo "Example (parse an existing log):   $0 2.9 -l /tmp/consoleText --nobuild --noclean -v"
  exit 1
}

VERBOSE=0
CLEANUP=1
doRhpkgContainerBuild=1

if [[ ! $WORKSPACE ]]; then
  WORKSPACE=$(mktemp -d)
fi
LOGFILE=${WORKSPACE}/get-sources.log.txt

while [[ "$#" -gt 0 ]]; do
  case $1 in
  '-n'|'--nobuild') doRhpkgContainerBuild=0; shift 0;;
  '--noclean') CLEANUP=0; shift 0;;
  '-s') SOURCEDIR="$2"; SOURCEDIR="${SOURCEDIR%/}"; shift 1;;
  '-l') LOGFILE="$2"; shift 1;;
  '-v') VERBOSE=1; shift 0;;
    *) JOB_BRANCH="$1"; shift 0;;
  esac
  shift 1
done

if [[ ! -d ${SOURCEDIR} ]] && [[ doRhpkgContainerBuild -eq 1 ]]; then usage; fi

if [[ ${doRhpkgContainerBuild} -eq 1 ]]; then
  # if not set, compute from current branch
  if [[ ! ${JOB_BRANCH} ]]; then 
    JOB_BRANCH=$(git rev-parse --abbrev-ref HEAD || true); JOB_BRANCH=${JOB_BRANCH//crw-}; JOB_BRANCH=${JOB_BRANCH%%-rhel*}
    if [[ ${JOB_BRANCH} == "2" ]]; then JOB_BRANCH="2.x"; fi
  fi
  pushd ${SOURCEDIR} >/dev/null
    # REQUIRE: rhpkg
    # get latest from Jenkins, then trigger a new OSBS build. Note: do not wrap JOB_BRANCH in quotes in case it includes trailing \n
    if [[ -f get-sources.sh ]]; then 
      ./get-sources.sh --force-build ${JOB_BRANCH} | tee "${LOGFILE}"
    elif [[ -f get-sources-jenkins.sh ]]; then # old name
      ./get-sources-jenkins.sh --force-build ${JOB_BRANCH} | tee "${LOGFILE}"
    else 
      echo "[ERROR] Could not run get-sources.sh or get-sources-jenkins.sh!"; exit 1
    fi
    wait
    cd ..
  popd >/dev/null
else
  if [[ ${VERBOSE} -eq 1 ]]; then echo "[INFO] Skip fetching sources and building in Brew"; fi
fi

#  "floating_tags": [
#      "latest",
#      "2.0"
#  ],
#  "pull": [
#      "registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-pluginregistry-rhel8@sha256:85c89a1d9e382bebe70f4204f05f06f0fc2b9c76f1c3ca2983c17989b92239fe",
#      "registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-pluginregistry-rhel8:2.0-212"
#  ],
#  "tags": [
#      "2.0-212"
#  ],

# set -x

# make sure these files exist, in case get-sources*.sh didn't produce useful output
touch "${LOGFILE}"

# get list of reg-proxy repo:tag as '2.y-zz'
TAGs=$(grep -E -A2 '"(tags|floating_tags)": \[' "${LOGFILE}" | grep -E -v "tags|\]|\[|--|latest" \
| grep -E "[0-9]+\.[0-9]+-[0-9]+" | tr -d ' "' | sort -urV || true)

# OPTION 1/3: Successful non-scratch build - compute build desc from tag(s)
echo "REPO_PATH=\"$(cat "${LOGFILE}" \
    | grep -E -A2 '"(pull)": \[' | grep -E -v "candidate" | grep -E "registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-" \
    | grep -E -v "@sha" | sed -r -e "s@.+\"(.+)\",*@\1@" | sort -u | tr -d "\n\r" )\"" \
    | tee "${WORKSPACE}"/build_desc.txt
source "${WORKSPACE}"/build_desc.txt
REPOS="${REPO_PATH}" # used for build description
if [[ $REPOS ]] && [[ ${VERBOSE} -eq 1 ]]; then echo "[INFO] #2 Console parser successful!"; fi

# # OPTION 1b/3: scratch build - Compute build desc with image created eg., "2.y-65 quay.io/crw/pluginregistry-rhel8:2.y-65"
# if [[ ! ${REPOS} ]] || [[ ${REPOS} == " " ]]; then
#   # for scratch builds look for this line:
#   # platform:- - atomic_reactor.plugins.tag_from_config - DEBUG - Using additional unique tag 
#   # rh-osbs/codeready-workspaces-server-rhel8:crw-2.0-rhel-8-containers-candidate-89319-20191122035915
#   echo "REPO_PATH=\"$(grep -E "platform:- - atomic_reactor.plugins.tag_from_config - DEBUG - Using additional unique tag " "${LOGFILE}" \
#     | grep -v grep | sed -r -e "s@.+Using additional primary tag (.+)@registry-proxy.engineering.redhat.com/\1@" | tr "\n\r" " " )\"" \
#     | tee "${WORKSPACE}"/build_desc.txt
#   source "${WORKSPACE}"/build_desc.txt
#   REPOS="${REPO_PATH}" # used for build description
#   if [[ $REPOS ]]; then echo "#2 Console parser successful!"; fi
# fi

# OPTION 2/3
if [[ ! ${REPOS} ]] || [[ ${REPOS} == " " ]]; then
  # for scratch builds look for this line:
  # ^ADD Dockerfile-codeready-workspaces-server-rhel8-2.0-scratch-89319-20191122035915 /root/buildinfo/Dockerfile-codeready-workspaces-server-rhel8-2.0-scratch-89319-20191122035915
  echo "REPO_PATH=\"$(grep -E "^ADD Dockerfile-codeready-workspaces-" "${LOGFILE}" \
    | sed -r -e "s@^ADD Dockerfile-codeready-workspaces-(.+) /root/.+@\1@" | sort -u | tr "\n\r" " " )\"" \
    | tee "${WORKSPACE}"/build_desc.txt
  source "${WORKSPACE}"/build_desc.txt
  REPOS="${REPO_PATH}" # used for build description
  if [[ $REPOS ]] && [[ ${VERBOSE} -eq 1 ]]; then echo "[INFO] #2 Console parser successful!"; fi
fi

# OPTION 3/3: unknown
if [[ ! ${REPOS} ]] || [[ ${REPOS} == " " ]]; then
  echo "REPO_PATH=\"BREW:BUILD/STATUS:UNKNOWN\"" | tee -a "${WORKSPACE}"/build_desc.txt
fi

# scrub dupe lines out of error log
ERRORS_FOUND=$(grep -E --text -B2 "Brew build has failed|failed with exit code|Problem loading ID|Finished: FAILURE" "${LOGFILE}" | \
  grep -v "grep" | \
  sed -r -e "s#[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3} -*##g" \
    -e "s# \(rc=1\)##g" \
    -e "s#\\\''##g" \
    -e "s#platform:- - atomic_reactor.inner - ##g" \
    \
    -e "s#atomic_reactor.inner - (ERROR|DEBUG) - ##g" \
    -e "s#atomic_reactor.plugins.imagebuilder - INFO - ##g" \
    -e "s#atomic_reactor.plugin - ##g" \
    -e 's#atomic_reactor.plugin.PluginFailedException: ##g' \
    -e 's#PluginFailedException: ##g' \
    \
    -e 's#Build step plugin imagebuilder failed: ##g' \
    -e 's#buildstep plugin failed: ##g' \
    -e 's#image build failed: ##g' \
    -e 's#build failed: ##g' \
    -e 's#caught exception ##g' \
    -e 's#\(PluginFailedException:  ##g' \
    -e 's#\{"imagebuilder": ##g' \
    \
    -e 's#.+(running (.+) failed with exit code [0-9]+).*#\1#g' \
    \
    -e 's#platform:- - ERROR - Build step plugin orchestrate_##g' \
    -e 's#^(INFO|LABEL| osbs\.|\[Pipeline\]).+##g' \
    -e 's#.+(atomic_reactor|raise PluginFailedException).+##g' \
    -e 's#.*(Dockerfile used for build:|End of Pipeline|Brew build has failed:|rm -f /tmp/tmp).*##g' \
    -e 's#ERROR - running##g' \
    `# remove short lines` \
    -e '/^.{,9}$/d' \
    | sort -u || true)
if [[ ${VERBOSE} -eq 1 ]]; then 
echo "[DEBUG] ERRORS_FOUND=
--------------------
${ERRORS_FOUND}
--------------------"; fi

TASK_URL="$(grep "Task info: https://brewweb.engineering.redhat.com/brew/taskinfo?taskID=" "${LOGFILE}" | grep -v grep | sed -e "s#Task info: ##" | head -1 || true)"
TASK_ID="${TASK_URL##*=}"
BUILD_DESC=$(echo $REPO_PATH | sed -r \
    -e 's#registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-#quay.io/crw/#g' \
    -e 's#(quay.io/crw/.+-rhel8:[0-9.-]+) *#<a href="https://\1">\1</a> #g' \
    -e 's#(quay.io/crw)/(operator|operator-metadata):([0-9.-]+) *#<a href="https://\1/crw-2-rhel8-\2:\3">\1/crw-2-rhel8-\2:\3</a> #g'
)
BUILD_RESULT="SUCCESS"
if [[ ${BUILD_DESC} == *"UNKNOWN"* ]]; then BUILD_RESULT="UNSTABLE"; fi
if [[ ${BUILD_DESC} == *"ERROR"* ]] || [[ ${BUILD_DESC} == *"FAILURE"* ]] || [[ ${ERRORS_FOUND} ]] || [[ ! ${TASK_URL} ]]; then BUILD_RESULT="FAILURE: ${ERRORS_FOUND}"; fi

# TODO using BUILD_DESC, TASK_URL, BUILD_RESULT, return string like this
descriptString="<a href='${TASK_URL}'>"
if [[ ${BUILD_RESULT} == *"FAILURE"* ]]; then 
  descriptString="${descriptString} Failed in "
else 
  descriptString="${descriptString} Build "
fi
descriptString="${descriptString} ${TASK_ID}</a> : ${BUILD_DESC}"
BUILD_DESC=${descriptString}

# cleanup
if [[ ${CLEANUP} -eq 1 ]]; then
  rm -f "${LOGFILE}"
fi

# collect these with grep 'TASK_URL=' /tmp/rhpkg-container-build.txt | sed -r -e "s#TASK_URL=##"
echo "TAGs=${TAGs}"
echo "TASK_URL=${TASK_URL}"
echo "BUILD_DESC=${BUILD_DESC}"
# BUILD_RESULT is a multiline string and so must be at the end of the output here, so it can be 
# easly collected by teeing to a file, then using sed -n '/BUILD_RESULT=/{:loop;n;p;b loop;}' ${WORKSPACE}/rhpkg-container-build.txt
echo "BUILD_RESULT="
echo "${BUILD_RESULT}"
