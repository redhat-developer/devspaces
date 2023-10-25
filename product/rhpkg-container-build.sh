#!/bin/bash -xe
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
SCRATCH_FLAGS=""
TARGET_FLAGS=""
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
  '--scratch') SCRATCH_FLAGS="--scratch"; shift 0;;
  *) CSV_VERSION="$1"; shift 0;;
  esac
  shift 1
done

if [[ ! -d ${SOURCEDIR} ]] && [[ doRhpkgContainerBuild -eq 1 ]]; then usage; fi

# TODO: CRW-1919 probably don't need to use a specific cache file - can use whatever default keyring is present
export KRB5CCNAME=/var/tmp/devspaces-build_ccache
klist

if [[ ${doRhpkgContainerBuild} -eq 1 ]]; then
  # if not set, compute from current branch
  if [[ ! ${JOB_BRANCH} ]]; then 
    JOB_BRANCH=$(git rev-parse --abbrev-ref HEAD || true); JOB_BRANCH=${JOB_BRANCH//devspaces-}; JOB_BRANCH=${JOB_BRANCH%%-rhel*}
    if [[ ${JOB_BRANCH} == "3" ]]; then JOB_BRANCH="3.x"; fi
  fi

  pushd ${SOURCEDIR} >/dev/null
    if [[ -f get-sources.sh ]]; then 
      # TODO remove these extra --target flags when we mave fully migrated to Cachito 
      # and no longer need a get-sources.sh script to run rhpkg
      if [[ $SCRATCH_FLAGS ]]; then
        if [[ $JOB_BRANCH == "3.x" ]] || [[ $JOB_BRANCH == "" ]]; then 
          TARGET_FLAGS="--target devspaces-3-rhel-8-containers-candidate"
        else
          TARGET_FLAGS="--target devspaces-${JOB_BRANCH}-rhel-8-containers-candidate"
        fi
      fi
      # invoke a non-cachito-friendly build with a special get-sources.sh
      # REQUIRE: rhpkg brewkoji
      ./get-sources.sh ${SCRATCH_FLAGS} --force-build -v ${CSV_VERSION} ${TARGET_FLAGS} | tee "${LOGFILE}"
    else 
      # invoke brew container-build
      # REQUIRE: brewkoji koji-containerbuild
      gitbranch="$(git rev-parse --abbrev-ref HEAD)"
      if [[ $SCRATCH_FLAGS == "--scratch" ]]; then gitbranch="devspaces-3-rhel-8"; fi
      target=${gitbranch}-containers-candidate
      repo="$(git remote -v | grep origin | head -1 | sed -r -e "s#.+/containers/(.+) \(fetch.+#\1#")"
      sha="$(git rev-parse HEAD)"
      brew container-build ${target} git+https://pkgs.devel.redhat.com/git/containers/${repo}#${sha} --git-branch ${gitbranch} --nowait ${SCRATCH_FLAGS} 2>/dev/null | tee -a 2>&1 "${LOGFILE}"
      taskID=$(grep "Created task:" "${LOGFILE}" | sed -e "s#Created task:##") && brew watch-logs $taskID | tee -a 2>&1 "${LOGFILE}"
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
#      "registry-proxy.engineering.redhat.com/rh-osbs/devspaces-pluginregistry-rhel8@sha256:85c89a1d9e382bebe70f4204f05f06f0fc2b9c76f1c3ca2983c17989b92239fe",
#      "registry-proxy.engineering.redhat.com/rh-osbs/devspaces-pluginregistry-rhel8:2.0-212"
#  ],
#  "tags": [
#      "2.0-212"
#  ],

# set -x

# make sure these files exist, in case get-sources*.sh didn't produce useful output
touch "${LOGFILE}"

# get list of reg-proxy repo:tag as '3.y-zz'
# force processing of log to be text (not binary); remove [2022-10-24T21:20:51.640Z] timestamps
# remove empty yaml and latest tags; find tags in x.y-zzz format
# remove quotes; sort unique by version
TAGs=$(grep --text -E -A2 '"(tags|floating_tags)": \[' "${LOGFILE}" | sed -r -e "s@\[[TZ0123456789.:-]+\]@@" | grep -E -v "tags|\]|\[|--|latest" \
| grep -E "[0-9]+\.[0-9]+-[0-9]+" | tr -d ' "' | sort -urV || true)

# OPTION 1/3: Successful non-scratch build - compute build desc from tag(s)
echo "REPO_PATH=\"$(cat "${LOGFILE}" \
    | grep --text -E -A2 '"(pull)": \[' | sed -r -e "s@\[[TZ0123456789.:-]+\]@@" | grep -E -v "candidate" | grep -E "registry-proxy.engineering.redhat.com/rh-osbs/devspaces-" \
    | grep -E -v "@sha" | sed -r -e "s@.+\"(.+)\",*@\1@" | sort -u | tr -d "\n\r" )\"" \
    | tee "${WORKSPACE}"/build_desc.txt
source "${WORKSPACE}"/build_desc.txt
REPOS="${REPO_PATH}" # used for build description
if [[ $REPOS ]] && [[ ${VERBOSE} -eq 1 ]]; then echo "[INFO] #2 Console parser successful!"; fi

# OPTION 2/3
if [[ ! ${REPOS} ]] || [[ ${REPOS} == " " ]]; then
  # for scratch builds look for this line:
  # ^ADD Dockerfile-devspaces-server-rhel8-2.0-scratch-89319-20191122035915 /root/buildinfo/Dockerfile-devspaces-server-rhel8-2.0-scratch-89319-20191122035915
  echo "REPO_PATH=\"$(grep --text -E "^ADD Dockerfile-devspaces-" "${LOGFILE}" | sed -r -e "s@\[[TZ0123456789.:-]+\]@@" \
    | sed -r -e "s@^ADD Dockerfile-devspaces-(.+) /root/.+@\1@" | sort -u | tr "\n\r" " " )\"" \
    | tee "${WORKSPACE}"/build_desc.txt
  source "${WORKSPACE}"/build_desc.txt
  REPOS="${REPO_PATH}" # used for build description
  if [[ $REPOS ]] && [[ ${VERBOSE} -eq 1 ]]; then echo "[INFO] #2 Console parser successful!"; fi
fi

# OPTION 3/3: unknown
if [[ ! ${REPOS} ]] || [[ ${REPOS} == " " ]]; then
  echo "REPO_PATH=\"BREW:BUILD/STATUS:UNKNOWN\"" | tee -a "${WORKSPACE}"/build_desc.txt
  source "${WORKSPACE}"/build_desc.txt
  REPOS="${REPO_PATH}" # used for build description
fi

# scrub dupe lines out of error log
ERRORS_FOUND=$(grep -E --text -B2 "Max retries exceeded with url: /brewhub|Failed to establish a new connection|Build failed \(rc=|Brew build has failed|failed with exit code|Problem loading ID|Finished: FAILURE|Error: error creating build container: committing the finished image|binary_container_postbuild failed" "${LOGFILE}" | \
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
    -e 's#binary_container_postbuild failed: ##g' \
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
    -e 's#.+Build failed \(rc=\{rc\}.+##g' \
    -e 's# +for line in output_lines:.*##g' \
    `# remove short lines` \
    -e '/^.{,9}$/d' \
    | sort -u || true)
if [[ ${VERBOSE} -eq 1 ]] || [[ ${ERRORS_FOUND} ]]; then 
echo "[DEBUG] ERRORS_FOUND=
--------------------
${ERRORS_FOUND}
--------------------"; fi

TASK_URL="$(grep --text "Task info: https://brewweb.engineering.redhat.com/brew/taskinfo?taskID=" "${LOGFILE}" | grep -v grep | sed -e "s#Task info: ##" | head -1 || true)"
TASK_ID="${TASK_URL##*=}"
BUILD_DESC=$(echo $REPO_PATH | sed -r \
    -e 's#registry-proxy.engineering.redhat.com/rh-osbs/devspaces-#quay.io/devspaces/#g' \
    -e 's#(quay.io/devspaces/.+-rhel8:[0-9.-]+) *#<a href="https://\1">\1</a> #g' \
    -e 's#(quay.io/devspaces)/(operator|operator-bundle):([0-9.-]+) *#<a href="https://\1/devspaces-3-rhel-8-\2:\3">\1/devspaces-3-rhel-8-\2:\3</a> #g'
)
BUILD_RESULT="SUCCESS"
if [[ ${BUILD_DESC} == *"UNKNOWN"* ]]; then BUILD_RESULT="UNSTABLE"; fi
if [[ ${BUILD_DESC} == *"ERROR"* ]] || [[ ${BUILD_DESC} == *"FAILURE"* ]] || [[ ${ERRORS_FOUND} ]] || [[ ! ${TASK_URL} ]]; then BUILD_RESULT="FAILURE: ${ERRORS_FOUND}"; fi
if [[ ${REPOS} == "BREW:BUILD/STATUS:UNKNOWN" ]]; then BUILD_RESULT="FAILURE: ${ERRORS_FOUND}"; fi

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
