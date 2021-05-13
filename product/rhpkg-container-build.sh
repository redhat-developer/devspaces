#!/bin/bash -xe
# this script is called by jenkins job of a similar name, get-sources-rhpkg-container-build
# 1. run the appropriate version of get-sources*.sh (which fetches or builds dependent binaries, then runs rhpkg container-build)
# 2. collect log information to report on build status

# params
JOB_BRANCH="" # 2.8, 2.9, 2.x
pushd ${WORKSPACE}/sources >/dev/null

# REQUIRE: rhpkg
# get latest from Jenkins, then trigger a new OSBS build. Note: do not wrap JOB_BRANCH in quotes in case it includes trailing \n
./get-sources-jenkins.sh --force-build ${JOB_BRANCH} | tee ${WORKSPACE}/get-sources-jenkins.log.txt
wait
cd ..
rm -fr sources

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

# make sure these files exist, in case get-sources-jenkins.sh didn't produce useful output
touch ${WORKSPACE}/get-sources-jenkins.log.txt

# get list of reg-proxy repo:tag as '2.y-zz'
TAGs=$(grep -E -A2 '"(tags|floating_tags)": \[' ${WORKSPACE}/get-sources-jenkins.log.txt | grep -E -v "tags|\]|\[|--|latest" \
| grep -E "[0-9]+\.[0-9]+-[0-9]+" | tr -d ' "' | sort -urV || true)

# OPTION 1/4: Compute build desc from tag(s)
echo "REPO_PATH=\"${TAGs}$(cat ${WORKSPACE}/get-sources-jenkins.log.txt \
    | grep -E -A2 '"(pull)": \[' | grep -E -v "candidate" | grep -E "registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-" \
    | grep -E -v "@sha" | sed -r -e "s@.+\"(.+)\",*@\1@" | tr "\n\r" " " )\"" \
    | tee ${WORKSPACE}/build_desc.txt
source ${WORKSPACE}/build_desc.txt
REPOS="${REPO_PATH}" # used for build description
if [[ $REPOS ]]; then echo "#1 Console parser successful!"; fi

# TODO make these console parsers smarter and remove all old flavours that don't work any more

# OPTION 2/4: Compute build desc with image created eg., "2.y-65 quay.io/crw/pluginregistry-rhel8:2.y-65"
if [[ ! ${REPOS} ]] || [[ ${REPOS} == " " ]]; then
  # for scratch builds look for this line:
  # platform:- - atomic_reactor.plugins.tag_from_config - DEBUG - Using additional unique tag 
  # rh-osbs/codeready-workspaces-server-rhel8:crw-2.0-rhel-8-containers-candidate-89319-20191122035915
  echo "REPO_PATH=\"$(grep -E "platform:- - atomic_reactor.plugins.tag_from_config - DEBUG - Using additional unique tag " ${WORKSPACE}/get-sources-jenkins.log.txt \
    | sed -r -e "s@.+Using additional primary tag (.+)@registry-proxy.engineering.redhat.com/\1@" | tr "\n\r" " " )\"" \
    | tee ${WORKSPACE}/build_desc.txt
  source ${WORKSPACE}/build_desc.txt
  REPOS="${REPO_PATH}" # used for build description
  if [[ $REPOS ]]; then echo "#2 Console parser successful!"; fi
fi

# OPTION 3/4
if [[ ! ${REPOS} ]] || [[ ${REPOS} == " " ]]; then
  # for scratch builds look for this line:
  # ^ADD Dockerfile-codeready-workspaces-server-rhel8-2.0-scratch-89319-20191122035915 /root/buildinfo/Dockerfile-codeready-workspaces-server-rhel8-2.0-scratch-89319-20191122035915
  echo "REPO_PATH=\"$(grep -E "^ADD Dockerfile-codeready-workspaces-" ${WORKSPACE}/get-sources-jenkins.log.txt \
    | sed -r -e "s@^ADD Dockerfile-codeready-workspaces-(.+) /root/.+@\1@" | tr "\n\r" " " )\"" \
    | tee ${WORKSPACE}/build_desc.txt
  source ${WORKSPACE}/build_desc.txt
  REPOS="${REPO_PATH}" # used for build description
  if [[ $REPOS ]]; then echo "#3 Console parser successful!"; fi
fi

if [[ ! ${REPOS} ]] || [[ ${REPOS} == " " ]]; then
  # OPTION 4/4: unknown
  echo "REPO_PATH=\"BREW:BUILD/STATUS:UNKNOWN\"" | tee -a ${WORKSPACE}/build_desc.txt
fi

ERRORS_FOUND=$(grep -E "Brew build has failed|failed with exit code|Problem loading ID" ${WORKSPACE}/get-sources-jenkins.log.txt || true)
NEW_TAG=$(grep -E -A2 '"tags": \[' ${WORKSPACE}/get-sources-jenkins.log.txt | grep -E -v "tags|\]|\[|--" | tr -d " " | uniq || true)
TASK_URL=$(grep "Task info: https://brewweb.engineering.redhat.com/brew/taskinfo?taskID=" ${WORKSPACE}/get-sources-jenkins.log.txt || true)
BUILD_DESC=$(cat ${WORKSPACE}/build_desc.txt | sed -r \
    -e 's#REPO_PATH="##g' \
    -e 's#"##g' \
    -e 's# #","#g' \
    -e 's#registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-#quay.io/crw/#g' \
    -e 's#(quay.io/crw/.+-rhel8:[0-9.-]+) #<a href="https://\1">\1</a> #g' \
    -e 's#(quay.io/crw)/(operator|operator-metadata):([0-9.-]+) #<a href="https://\1/crw-2-rhel8-\2:\3">\1/crw-2-rhel8-\2:\3</a> #g'
)
BUILD_RESULT="SUCCESS"
if [[ ${BUILD_DESC} == *"ERROR"* ]] || [[ ${ERRORS_FOUND} ]] || [[ ! ${TASK_URL} ]]; then BUILD_RESULT="FAILURE: ${ERRORS_FOUND}"; fi
if [[ ${BUILD_DESC} == *"UNKNOWN"* ]]; then BUILD_RESULT="UNSTABLE"; fi

# TODO using BUILD_DESC, TASK_URL, BUILD_RESULT, return string like this
descriptString="<a href='${TASK_URL}'>"
if [[ ${BUILD_RESULT} ==.result.equals("FAILURE") ? "Failed in ":"Build ") + TASK_URL.replaceAll(".+taskID=","") + "</a> : " + BUILD_DESC