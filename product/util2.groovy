import groovy.transform.Field

@Field String CSV_VERSION_F = ""
// Requires installYq()
def String getCSVVersion(String MIDSTM_BRANCH) {
  if (CSV_VERSION_F.equals("")) {
    CSV_VERSION_F = sh(script: '''#!/bin/bash -xe
    curl -sSLo- https://raw.githubusercontent.com/redhat-developer/devspaces-images/''' + MIDSTM_BRANCH + '''/devspaces-operator-bundle/manifests/devspaces.csv.yaml | yq -r .spec.version''', returnStdout: true).trim()
  }
  // CRW-2039 check that CSV version is aligned to DS version, and throw warning w/ call to action to avoid surprises
  if (DS_VERSION_F.equals("")) {
    DS_VERSION_F = getDsVersion(MIDSTM_BRANCH)
  }
  CSV_VERSION_BASE=CSV_VERSION_F.replaceAll("([0-9]+\\.[0-9]+)\\.[0-9]+","\$1"); // extract 3.yy from 3.yy.z
  if (!CSV_VERSION_BASE.equals(DS_VERSION_F)) {
    println "[WARNING] CSV version (from getCSVVersion() -> csv.yaml = " + CSV_VERSION_F + 
      ") does not match DS version (from getDsVersion() -> VERSION = " + DS_VERSION_F + ") !"
    println "This could mean that your VERSION file or CSV file update processes have not run correctly."
    println "Check these jobs:"
    println "* https://main-jenkins-csb-crwqe.apps.ocp-c1.prod.psi.redhat.com/job/DS_CI/job/Releng/job/update-version-and-registry-tags/ "
    println "* https://main-jenkins-csb-crwqe.apps.ocp-c1.prod.psi.redhat.com/job/DS_CI/job/operator-bundle_" + getJobBranch(MIDSTM_BRANCH)
    println "Check these files:"
    println "https://raw.githubusercontent.com/redhat-developer/devspaces/" + MIDSTM_BRANCH + "/dependencies/VERSION"
    println "https://github.com/redhat-developer/devspaces-images/blob/" + MIDSTM_BRANCH + "/devspaces-operator-bundle/manifests/devspaces.csv.yaml"
    println "https://github.com/redhat-developer/devspaces-images/blob/" + MIDSTM_BRANCH + "/devspaces-operator-bundle-generated/manifests/devspaces.csv.yaml"
  }

  return CSV_VERSION_F
}

@Field String DS_VERSION_F = ""
@Field String DS_BRANCH_F = ""
def String getDsVersion(String MIDSTM_BRANCH) {
  if (DS_VERSION_F.equals("")) {
    DS_BRANCH_F = MIDSTM_BRANCH
    DS_VERSION_F = sh(script: '''#!/bin/bash -xe
    curl -sSLo- https://raw.githubusercontent.com/redhat-developer/devspaces/''' + MIDSTM_BRANCH + '''/dependencies/VERSION''', returnStdout: true).trim()
  }
  return DS_VERSION_F
}

@Field String JOB_BRANCH
// JOB_BRANCH defines which set of jobs to run, eg., dashboard_ + JOB_BRANCH
def String getJobBranch(String MIDSTM_BRANCH) {
  if (JOB_BRANCH.equals("") || JOB_BRANCH == null) {
    if (MIDSTM_BRANCH.equals("devspaces-3-rhel-8") || MIDSTM_BRANCH.equals("main")) {
      JOB_BRANCH="3.x"
    } else {
      // for 3.y (and 2.y)
      JOB_BRANCH=MIDSTM_BRANCH.replaceAll("devspaces-","").replaceAll("crw-","").replaceAll("-rhel-8","")
    }
  }
  return JOB_BRANCH
}

// method to check for global var or job param; if not set, return nullstring and throw no MissingPropertyException
// thanks to https://stackoverflow.com/questions/42465028/how-can-i-determine-if-a-variable-exists-from-within-the-groovy-code-running-in
// Usage: globalVar({nodeVersion}) <-- braces are required
def globalVar(varNameExpr) {
  try {
    varNameExpr() // return value of the string if defined by global var or job param
  } catch (exc) {
    "" // return nullstring if not defined
  }
}

def cloneRepo(String URL, String REPO_PATH, String BRANCH, boolean withPolling=false, String excludeRegions='', String includeRegions='*') {
  if (URL.indexOf("pkgs.devel.redhat.com") == -1) {
    // remove http(s) prefix, then trim any token@ prefix too
    URL=URL - ~/http(s*):\/\// - ~/.*@/
    def AUTH_URL_SHELL='https://\$GITHUB_TOKEN:x-oauth-basic@' + URL
    def AUTH_URL_GROOVY='https://$GITHUB_TOKEN:x-oauth-basic@' + URL
    if (!fileExists(REPO_PATH) || withPolling) {
      // clean before checkout
      sh('''rm -fr ${WORKSPACE}/''' + REPO_PATH)
      checkout(
        poll: withPolling,
        changelog: withPolling,
        scm: [
          $class: 'GitSCM',
          branches: [[name: BRANCH]],
          clean: true,
          doGenerateSubmoduleConfigurations: false,
          extensions: [
            [$class: 'RelativeTargetDirectory', relativeTargetDir: REPO_PATH],
            [$class: 'PathRestriction', excludedRegions: excludeRegions, includedRegions: includeRegions]
          ],
          submoduleCfg: [],
          userRemoteConfigs: [[url: AUTH_URL_GROOVY]]
        ]
      )
    }
    sh('''#!/bin/bash -xe
cd ''' + REPO_PATH + '''
git checkout --track origin/''' + BRANCH + ''' || true
export GITHUB_TOKEN=''' + GITHUB_TOKEN + ''' # echo "''' + GITHUB_TOKEN + '''"
git config user.email "nickboldt+devstudio-release@gmail.com"
git config user.name "devstudio-release"
git config --global push.default matching
# fix for warning: Pulling without specifying how to reconcile divergent branches is discouraged
git config --global pull.rebase true
# Fix for Could not read Username / No such device or address :: https://github.com/github/hub/issues/1644
git config --global hub.protocol https
git remote set-url origin ''' + AUTH_URL_SHELL + '''
'''
    )
  } else {
    if (!fileExists(REPO_PATH)) {
      sh('''#!/bin/bash -xe
export KRB5CCNAME=/var/tmp/devspaces-build_ccache
kinit -k -t /home/hudson/devspaces-build-keytab devspaces-build@IPA.REDHAT.COM || true; klist
git clone ''' + URL + ''' ''' + REPO_PATH
      )
    }
    sh('''#!/bin/bash -xe
export KRB5CCNAME=/var/tmp/devspaces-build_ccache
kinit -k -t /home/hudson/devspaces-build-keytab devspaces-build@IPA.REDHAT.COM || true; klist
cd ''' + REPO_PATH + '''
git checkout --track origin/''' + BRANCH + ''' || true
git config user.email devspaces-build@redhat.com
git config user.name "Dev Spaces Build"
git config --global push.default matching
# fix for warning: Pulling without specifying how to reconcile divergent branches is discouraged
git config --global pull.rebase true
'''
    )
  }
}

// Requires getDsVersion() to set DS_BRANCH_F in order to install correct version of the script; or, if JOB_BRANCH is defined by .groovy param or in .jenkinsfile, will use that version
def updateBaseImages(String REPO_PATH, String SOURCES_BRANCH, String FLAGS="", String SCRIPTS_BRANCH="") {
  def String updateBaseImages_bin="${WORKSPACE}/updateBaseImages.sh"
  if (SOURCES_BRANCH?.trim() && !DS_BRANCH_F?.trim()) {
    getDsVersion(SOURCES_BRANCH)
  }
  if (!SCRIPTS_BRANCH?.trim() && DS_BRANCH_F?.trim()) {
    SCRIPTS_BRANCH = DS_BRANCH_F // this should work for midstream/downstream branches like devspaces-3.1-rhel-8
  } else if (!SCRIPTS_BRANCH?.trim() && MIDSTM_BRANCH?.trim()) {
    SCRIPTS_BRANCH = MIDSTM_BRANCH // this should work for midstream/downstream branches like devspaces-3.1-rhel-8
  } else if (!SCRIPTS_BRANCH?.trim() && JOB_BRANCH?.trim()) {
    SCRIPTS_BRANCH = JOB_BRANCH // this might fail if the JOB_BRANCH is 2.6 and there's no such branch
  }
  // fail build if not true
  assert (DS_BRANCH_F?.trim()) : "ERROR: execute getDsVersion() before calling updateBaseImages()"

  if (!fileExists(updateBaseImages_bin)) {
    // otherwise continue
    sh('''#!/bin/bash -xe
URL="https://raw.githubusercontent.com/redhat-developer/devspaces/''' + SCRIPTS_BRANCH + '''/product/updateBaseImages.sh"
# check for 404 and fail if can't load the file
header404="$(curl -sSLI ${URL} | grep -E -v "id: |^x-" | grep -v "content-length" | grep -E "404|Not Found" || true)"
if [[ $header404 ]]; then
  echo "[ERROR] Can not resolved $URL : $header404 "
  echo "[ERROR] Please check the value of SCRIPTS_BRANCH = ''' + SCRIPTS_BRANCH + ''' to confirm it's a valid branch."
  exit 1
else
  curl -sSL ${URL} -o ''' + updateBaseImages_bin + ''' && chmod +x ''' + updateBaseImages_bin + '''
fi
    ''')
  }
  // NOTE: b = sources branch, sb = scripts branch
  // TODO - https://issues.redhat.com/browse/CRW-3153 connection on x86_64-rhel8-3640 OK, fails on cpt-ppc-006, so enable -v (verbose) flag so we can see what's happening more clearly
  updateBaseImages_cmd='''
echo "[INFO] util.groovy :: updateBaseImages :: SOURCES_BRANCH = ''' + SOURCES_BRANCH + '''"
echo "[INFO] util.groovy :: updateBaseImages :: SCRIPTS_BRANCH = ''' + SCRIPTS_BRANCH + '''"
cd ''' + REPO_PATH + '''
''' + updateBaseImages_bin + ''' --sources-branch ''' + SOURCES_BRANCH + ''' --scripts-branch ''' + SCRIPTS_BRANCH + ''' ''' + FLAGS + ''' || true
'''
  is_pkgsdevel = sh(script: '''#!/bin/bash -xe
cd ''' + REPO_PATH + '''; git remote -v | grep pkgs.devel.redhat.com || true''', returnStdout: true).trim()
  if (is_pkgsdevel?.trim()) {
    sh('''#!/bin/bash -xe
export KRB5CCNAME=/var/tmp/devspaces-build_ccache
kinit -k -t /home/hudson/devspaces-build-keytab devspaces-build@IPA.REDHAT.COM || true; klist
''' + updateBaseImages_cmd
    )
  } else {
    assert (GITHUB_TOKEN?.trim()) : "ERROR: GITHUB_TOKEN is not set; must be defined in order to manipulate github repos"
    sh('''#!/bin/bash -xe
export GITHUB_TOKEN="''' + GITHUB_TOKEN + '''"
''' + updateBaseImages_cmd
)
  }
}

// return a short SHA by default (4-char if possible, longer if required for uniqueness); or use num_digits=40 for a full length SHA
def getLastCommitSHA(String REPO_PATH, int num_digits=4) {
  return sh(script: '''#!/bin/bash -xe
    cd ''' + REPO_PATH + '''
    git rev-parse --short=''' + num_digits + ''' HEAD''', returnStdout: true).trim()
}

def getDSLongName(String SHORT_NAME) {
  return "devspaces-" + SHORT_NAME
}

def getDSShortName(String LONG_NAME) {
  return LONG_NAME.minus("devspaces-")
}

// see https://hdn.corp.redhat.com/rhel7-csb-stage/repoview/redhat-internal-cert-install.html
// and https://hdn.corp.redhat.com/rhel7-csb-stage/RPMS/noarch/?C=M;O=D
def installRedHatInternalCerts() {
  sh('''#!/bin/bash -xe
  if [[ ! $(rpm -qa | grep redhat-internal-cert-install || true) ]]; then
    cd /tmp
    # 403 access on https://hdn.corp.redhat.com/rhel7-csb-stage/RPMS/noarch/redhat-internal-cert-install-0.1-24.el7.noarch.rpm
    # so use latest csb.noarch file instead 
    rpm=$(curl --insecure -sSLo- "https://hdn.corp.redhat.com/rhel7-csb-stage/RPMS/noarch/?C=M;O=D" | grep cert-install | grep "csb.noarch" | head -1 | sed -r -e 's#.+>(redhat-internal-cert-install-.+[^<])</a.+#\\1#')
    curl --insecure -sSLO https://hdn.corp.redhat.com/rhel7-csb-stage/RPMS/noarch/${rpm}
    sudo yum -y install ${rpm}
    rm -fr /tmp/${rpm}
  fi
  ''')
}

// CRW-3598: @since 3.5
// note that this URL is also in devspaces-chectl/build/scripts/build.sh and devspaces/product/manifest/get-3rd-party-sources.sh
// also mentioned in dsc.groovy and get-3rd-party-sources.groovy
def getStagingHost() {
  return "devspaces-build@spmm-util.hosts.prod.psi.bos.redhat.com"
}

@Field String defaultFailedEmailRecipients='sdawley@redhat.com'
def notifyBuildFailed(String details="", String toRecipients=defaultFailedEmailRecipients) {
    emailext (
        subject: "Build failed in Jenkins: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
        body: details + """

Build failed in Jenkins: ${env.JOB_NAME} #${env.BUILD_NUMBER}

Build:   ${env.BUILD_URL}
Steps:   ${env.BUILD_URL}/flowGraphTable

Params:  ${env.BUILD_URL}/parameters
Console: ${env.BUILD_URL}/console

Rebuild: ${env.BUILD_URL}/rebuild
""",
        // [$class: 'CulpritsRecipientProvider'],[$class: 'DevelopersRecipientProvider']]
        recipientProviders: [culprits(), developers(), requestor()],
        to: toRecipients
    )
}

// commit all changed files in dir with message to branch
def commitChanges(String dir, String message, String branch) {
  sh('''#!/bin/bash -xe
cd ''' + dir + ''' || exit 1
if [[ \$(git diff --name-only) ]]; then # file changed
  git add --all -f . || true
  git commit -s -m "''' + message + '''" || true
  git push origin ''' + branch + ''' || true
fi
  ''')
}

// ensure static Dockerfiles have the correct version encoded in them, then commit changes
def updateDockerfileVersions(String dir="${WORKSPACE}/sources", String branch=MIDSTM_BRANCH, String DS_VERSION=DS_VERSION_F) {
  sh('''#!/bin/bash -e
echo "[INFO] Run util.updateDockerfileVersions('''+dir+''', '''+branch+''', '''+DS_VERSION+''')"
cd ''' + dir + ''' || exit 1
for d in $(find . -name "*ockerfile*" -type f); do
  sed -i $d -r -e 's#version="[0-9.]+"#version="''' + DS_VERSION + '''"#g' || true
done
  ''')
  commitChanges(dir, "[sync] Update Dockerfiles to latest version = " + DS_VERSION, branch)
}

// call getLatestRPM.sh -s SOURCE_DIR -r RPM_PATTERN  -u BASE_URL -a 'ARCH1 ... ARCHN' -q
// will also update content_sets.* files too, if ocp version has changed
def updateRpms(String RPM_PATTERN, String BASE_URL, String dir="${WORKSPACE}/sources", String branch=MIDSTM_BRANCH, String ARCHES="x86_64 s390x ppc64le") {
  return sh(returnStdout: true, script: '''#!/bin/bash -xe
if [[ ! -x getLatestRPM.sh ]]; then 
  curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/''' + branch + '''/product/getLatestRPM.sh && chmod +x getLatestRPM.sh
fi
./getLatestRPM.sh -r "''' + RPM_PATTERN + '''" -u "''' + BASE_URL + '''" -s "''' + dir + '''" -a "''' + ARCHES + '''" -q
  ''').trim()
}

// URL from which to get internal RPM installations
@Field String pulpRepoURL = "https://rhsm-pulp.corp.redhat.com"

// ./getLatestRPM.sh -r "openshift-clients-4" -u https://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/basearch/rhocp/4.12 -s ...
def updateOCRpms(String rpmRepoVersion="4.11", String dir="${WORKSPACE}/sources", String branch=MIDSTM_BRANCH, String ARCHES="x86_64 s390x ppc64le") {
  updatedVersion=updateRpms("openshift-clients-4", pulpRepoURL + "/content/dist/layered/rhel8/basearch/rhocp/" + rpmRepoVersion, dir, branch, ARCHES)
  commitChanges(dir, "[rpms] Update to " + updatedVersion, branch)
}
// ./getLatestRPM.sh -r "odo-3"             -u https://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/basearch/ocp-tools/4.11 -s ...
def updateOdoRpms(String rpmRepoVersion="4.11", String dir="${WORKSPACE}/sources", String branch=MIDSTM_BRANCH, String ARCHES="x86_64 s390x ppc64le") {
  updatedVersion=updateRpms("odo-3", pulpRepoURL + "/content/dist/layered/rhel8/basearch/ocp-tools/" + rpmRepoVersion, dir, branch, ARCHES)
  commitChanges(dir, "[rpms] Update to " + updatedVersion, branch)
}
// ./getLatestRPM.sh -r "helm-3"             -u https://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/basearch/ocp-tools/4.11 -s ...
def updateHelmRpms(String rpmRepoVersion="4.11", String dir="${WORKSPACE}/sources", String branch=MIDSTM_BRANCH, String ARCHES="x86_64 s390x ppc64le") {
  updatedVersion=updateRpms("helm-3", pulpRepoURL + "/content/dist/layered/rhel8/basearch/ocp-tools/" + rpmRepoVersion, dir, branch, ARCHES)
  commitChanges(dir, "[rpms] Update to " + updatedVersion, branch)
}

// run a job with default token, FORCE_BUILD=true, and SCRATCH=false
// use jobPath = /job/folder/job/jobname so we can both invoke a job, and then use json API in getLastSuccessfulBuildId()
def runJob(String jobPath, boolean doWait=false, boolean doPropagateStatus=true, String jenkinsURL=JENKINS_URL, String TIMEOUT="180") {
  def int prevSuccessBuildId = getLastSuccessfulBuildId(jenkinsURL + jobPath) // eg., #5
  println ("runJob(" + jobPath + ") :: prevSuccessBuildId = " + prevSuccessBuildId)
  final jobResult = build(
    // convert jobPath /job/folder/job/jobname (used in json API in getLastSuccessfulBuildId() to /folder/jobname (used in build())
    job: jobPath.replaceAll("/job/","/"),
    wait: doWait,
    propagate: doPropagateStatus,
    quietPeriod: 0,
    parameters: [
      [
        $class: 'StringParameterValue',
        name: 'TIMEOUT',
        value: TIMEOUT
      ],
      [
        $class: 'BooleanParameterValue',
        name: 'FORCE_BUILD',
        value: true
      ],
      [
        $class: 'BooleanParameterValue',
        name: 'SCRATCH',
        value: false
      ]
    ]
  )
  // wait until #5 -> #6
  jobLink=jobPath + "/" +  (prevSuccessBuildId + 1).toString()
  triggerDesc="<br/>=?> Job <a href=${JENKINS_URL}${jobLink}/>${jobPath} #" + (prevSuccessBuildId + 1).toString() + " triggered</a>"
  if (doWait) { 
    println("waiting for runJob(" + jobPath + ") :: prevSuccessBuildId = " + prevSuccessBuildId)
    currentBuild.description+=triggerDesc + " [waiting]"
    if (!waitForNewBuild(jenkinsURL + jobPath, prevSuccessBuildId)) { 
      jobLink=jobPath + "/" +  jobResult?.number?.toString()
      println("--x Job ${JENKINS_URL}${jobLink}/console failed!")
      currentBuild.description+="<br/>* <b style='color:red'>FAILED: <a href=${jobLink}/console>" + (jobLink.replaceAll("/job/","/")) + "</a></b>"
      currentBuild.result = 'FAILED'
      notifyBuildFailed(currentBuild.description,defaultFailedEmailRecipients)
    }
    println("++> Job ${JENKINS_URL}${jobLink}/console completed.")
  } else {
    println("=?> Job ${JENKINS_URL}${jobLink} triggered.")
    currentBuild.description+=triggerDesc + " [no wait]"
  }
  return getLastSuccessfulBuildId(jenkinsURL + jobPath)
}

/* 
lastBuild: build in progress -- if running, .result = null; else "FAILURE", "SUCCESS", etc
lastSuccessfulBuild
lastFailedBuild
*/
def getBuildJSON(String url, String buildType, String field) {
  return sh(returnStdout: true, script: '''
URL="''' + url + '''/''' + buildType + '''/api/json"
# check for 404 and return 0 if can't load, or the actual value if loaded
header404="$(curl --insecure -sSLI ${URL} | grep -E -v "id: |^x-" | grep -v "content-length" | grep -E "404|Not Found" || true)"
if [[ $header404 ]]; then # echo "[WARNING] Can not resolve ${URL} : $header404 "
  echo 0
else
  curl --insecure -sSLo- ${URL} | jq -r "''' + field + '''"
fi
''').trim()
}
def getLastBuildId(String url) {
  return (getBuildJSON(url, "lastBuild", ".number") as int)
}
def getLastBuildResult(String url) {
  return getBuildJSON(url, "lastBuild", ".result")
}
def getLastSuccessfulBuildId(String url) {
  return (getBuildJSON(url, "lastSuccessfulBuild", ".number") as int)
}
def getLastFailedBuildId(String url) {
  return (getBuildJSON(url, "lastFailedBuild", ".number") as int)
}
def getLastUnsuccessfulBuildId(String url) {
  return (getBuildJSON(url, "lastUnsuccessfulBuild", ".number") as int)
}

// default timeout = 7200s = 2h
def waitForNewBuild(String jobURL, int oldId, int checkInterval=120, int timeout=7200) {
  echo "Id baseline for " + jobURL + "/lastBuild :: " + oldId
  elapsed=0
  nextId=oldId+1
  while (true) {
      newId=getLastSuccessfulBuildId(jobURL)
      if (newId > oldId && getLastBuildResult(jobURL).equals("SUCCESS")) {
          println "Id rebuilt in " + elapsed + "s (SUCCESS): " + jobURL + "/" + newId
          return true
          break
      } else {
        newId=getLastBuildId(jobURL)
        if (newId > oldId && getLastFailedBuildId(jobURL).equals(newId)) {
          println "Id rebuilt in " + elapsed + "s (FAILURE): " + jobURL + "/" + newId
          return false
          break
        } else if (newId > oldId && getLastUnsuccessfulBuildId(jobURL).equals(newId)) {
          println "Id rebuilt in " + elapsed + "s (ABORTED): " + jobURL + "/" + newId
          return false
          break
        }
        if (newId > oldId && getLastBuildResult(jobURL).equals("FAILURE")) {
          println "Id rebuilt in " + elapsed + "s (FAILURE): " + jobURL + "/" + newId
          return false
          break
        } else if (newId > oldId && getLastBuildResult(jobURL).equals("ABORTED")) {
          println "Id rebuilt in " + elapsed + "s (ABORTED): " + jobURL + "/" + newId
          return false
          break
        }
      }
      sleep(time:checkInterval,unit:"SECONDS")
      elapsed += checkInterval
      if (elapsed >= timeout) {
        println "ERROR: No new build #" + newId + " > #" + oldId + " found after " + elapsed + " elapsed seconds!"
        return false
        break
      } else {
        println "Waiting " + checkInterval + "s for " + jobURL + "/" + nextId + " to complete"
      }
  }
  return true
}

// requires brew, skopeo, jq, yq
// for a given image, return latest image tag in quay
def getLatestImageAndTag(String orgAndImage, String repo="quay", String tag=DS_VERSION_F) {
  sh '''#!/bin/bash -xe
if [[ ! -x getLatestImageTags.sh ]]; then 
  curl -sSLO https://raw.githubusercontent.com/redhat-developer/devspaces/''' + MIDSTM_BRANCH + '''/product/getLatestImageTags.sh && chmod +x getLatestImageTags.sh
fi
'''
  return sh(
    returnStdout: true, 
    // -b devspaces-3.0-rhel-8 -c devspaces/server-rhel8 --tag "3.0-" --quay
    script: './getLatestImageTags.sh -b ' + MIDSTM_BRANCH + ' -c "' + orgAndImage + '" --tag "' + tag + '" --' + repo
  ).trim()
}

// requires brew, skopeo, jq, yq
// check for latest image tags in quay for a given image
// default timeout = 7200s = 2h
def waitForNewQuayImage(String orgAndImage, String oldImage, int checkInterval=120, int timeout=7200) {
  echo "Image baseline: " + oldImage
  elapsed=0
  while (true) {
      def newImage = getLatestImageAndTag(orgAndImage, "quay")
      // use bash version sort to put largest imageAndTag on top, then select that imageAndTag
      def newestImage = sh(script: 'echo -e "' + oldImage + '\n' + newImage + '" | grep -v "???" | sort -uVr | head -1', returnStdout: true).trim()
      // if the new image is different from the old one, and the newest image is not the old one, then we have a newer image
      if (!newImage.equals(oldImage) && !newestImage.equals(oldImage)) {
          echo "Image rebuilt in " + elapsed + "s (SUCCESS): " + newImage
            return true
          break
      }
      sleep(time:checkInterval,unit:"SECONDS")
      elapsed += checkInterval
      if (elapsed >= timeout) {
            println "ERROR: No new build #" + newImage + " > #" + oldImage + " found after " + elapsed + " elapsed seconds!"
            return false
            break
      } else {
        println "Waiting " + checkInterval + "s for newer build than " + oldImage
      }
  }
  return true
}

// depends on rpm perl-Digest-SHA for 'shasum -a ZZZ', or rpm coreutils for 'shaZZZsum'
// createSums("${DS_path}/*/target/", "*.tar.*")
def createSums(String filePath, String filePattern, String algorithm=512) {
  sh '''#!/bin/bash -xe
suffix=".sha''' + algorithm + '''"
# delete any existing .shaZZZ files so we don't accidentally use them as shasum input if filePattern is too aggressive
for d in $(find ''' + filePath + ''' -name "''' + filePattern + '''${suffix}"); do
  rm -f $d
done

# create new .shaZZZ files
prefix="SHA''' + algorithm + '''"
for d in $(find ''' + filePath + ''' -name "''' + filePattern + '''"); do
  sum=""
  if [[ -x /usr/bin/sha''' + algorithm + '''sum ]]; then
    sum="$(/usr/bin/sha''' + algorithm + '''sum $d)"
  elif [[ -x /usr/bin/shasum ]]; then
    sum="$(/usr/bin/shasum -a ''' + algorithm + ''' $d)"
  else
    echo "[ERROR] Could not find /usr/bin/shasum or /usr/bin/sha''' + algorithm + '''sum!"
    echo "[ERROR] Install rpm package perl-Digest-SHA for shasum, or coreutils for shaZZZsum to proceed."
    exit 1
  fi
  if [[ ${sum} != "" ]]; then
    echo "${sum}" | sed -r -e "s#  ${d}##" -e "s#^#${prefix} (${d##*/}) = #" > ${d}${suffix}
  else
    echo "[ERROR] No ${prefix} sum calculated for ${d} !"
    exit 1
  fi
done
'''
}

// return false if URL is 404'd
def checkURL(String URL) {
  def statusCode = sh(script: '''#!/bin/bash -xe
# check for 404 and fail if can't load the file
URL="''' + URL + '''"
header404="$(curl --insecure -sSLI "${URL}" | grep -E -v "id: |^x-" | grep -v "content-length" | grep -E "404|Not Found" || true)"
if [[ $header404 ]]; then
  echo "[ERROR] Can not resolve $URL : $header404 "
  exit 1
fi
exit 0
  ''', returnStatus: true)
  return statusCode > 1 ? false : true
}

boolean hasSuccessfullyBuiltAllArches(String containerYamlPath, String jobOutput) {
  int containerBuildCount = sh(script: '''#!/bin/bash -xe
    yq -r ".platforms.only | length" ''' + containerYamlPath, returnStdout: true).trim()
    echo "Expected number of container builds (arches in container.yaml): "+containerBuildCount
  int containerSuccessCount = jobOutput.count("Build finished successfully! Pushing image to ")
    echo "Successful builds detected: "+containerSuccessCount
  // should get 1 per arch + 1 overall success, which is 1 more than list in container.yaml
  if (containerSuccessCount > containerBuildCount) { 
    return true
  } else {
    return false
  }
}

String prepareHTMLStringForJSON(String input) {
  return input.replaceAll("<([a-z]+)/>","<\$1 />").replaceAll("\n","").replaceAll("/>","\\/>")
}

String buildResultBadge() {
  def currentBuildResult = currentBuild.result?.trim().toString()
  println("currentBuildResult = " + currentBuildResult)
  def badge = currentBuildResult
  switch(currentBuildResult) {
    case ["SUCCESS", "", "null", null]:
      badge = "![SUCCESS](https://img.shields.io/badge/Build-SUCCESS-brightgreen?style=plastic&logo=redhat)"
      break
    case "UNSTABLE":
      badge = "![UNSTABLE](https://img.shields.io/badge/Build-UNSTABLE-yellow?style=plastic&logo=redhat)"
      break
    case "ABORTED":
      badge = "![ABORTED](https://img.shields.io/badge/Build-ABORTED-lightgrey?style=plastic&logo=redhat)"
      break
    case "FAILURE":
      badge = "![FAILURE](https://img.shields.io/badge/Build-FAILURE-red?style=plastic&logo=redhat)"
      break
    default:
      badge = "![UNKNOWN](https://img.shields.io/badge/Build-UNKNOWN-blue?style=plastic&logo=redhat)"
      break
  }
  return "[" + badge + "](" + currentBuild.absoluteUrl+")"
}

String defaultPullRequestCommentBuildDescription(String MIDSTM_BRANCH) {
  return prepareHTMLStringForJSON(defaultPullRequestCommentHeader(MIDSTM_BRANCH) + \
    buildResultBadge() + "<br /><blockquote>" + currentBuild.description + "</blockquote>")
}

String defaultPullRequestCommentHeader(String MIDSTM_BRANCH) {
  return "Build [" + getDsVersion(MIDSTM_BRANCH) + "](https://github.com/redhat-developer/devspaces-images/tree/" + MIDSTM_BRANCH + "/) :: [" + \
    currentBuild.absoluteUrl.replaceAll(".+/([^/]+/[0-9]+)/","\$1") + "](" + currentBuild.absoluteUrl+"): "
}
// formatted for submission via JSON
String defaultPullRequestComment (String MIDSTM_BRANCH) {
  def comment = \
  defaultPullRequestCommentHeader(MIDSTM_BRANCH) + \
  "[Console](" + currentBuild.absoluteUrl + "console), " + \
  "[Changes](" + currentBuild.absoluteUrl + "changes), " + \
  "[Git Data](" + currentBuild.absoluteUrl + "git)"
  return comment
}

// convenience methods to comment with build URL or description
String commentOnPullRequestBuildLinks(String ownerRepo, String SHA) {
  return commentOnPullRequest(ownerRepo, SHA, defaultPullRequestComment(MIDSTM_BRANCH))
}
String commentOnPullRequestBuildLinks(String comments_url) {
  return commentOnPullRequest(comments_url, defaultPullRequestComment(MIDSTM_BRANCH))
}
String commentOnPullRequestBuildDescription(String ownerRepo, String SHA) {
  return commentOnPullRequest(ownerRepo, SHA, defaultPullRequestCommentBuildDescription(MIDSTM_BRANCH))
}
String commentOnPullRequestBuildDescription(String comments_url) {
  return commentOnPullRequest(comments_url, defaultPullRequestCommentBuildDescription(MIDSTM_BRANCH))
}

// given a repo and commit SHA, compute PR comments_url like https://api.github.com/repos/redhat-developer/devspaces/issues/848/comments
// then publish a message to that URL 
// return comments_url (with comment hash) so we can pass that to downstream jobs
String commentOnPullRequest(String ownerRepo, String SHA, String message) {
  def comments_url = sh(script: '''#!/bin/bash -xe
export GITHUB_TOKEN=''' + GITHUB_TOKEN + ''' # echo "''' + GITHUB_TOKEN + '''"
ownerRepo="''' + ownerRepo + '''"
SHA="''' + SHA + '''"
# use gh to query a given repo for closed pulls for a given commitSHA; return the PR URL
curl -sSL -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github.v3+json" \\
  "https://api.github.com/repos/${ownerRepo}/pulls?state=closed" | yq -r --arg SHA "$SHA" '.[]|select(.merge_commit_sha == $SHA or .head.sha == $SHA)|.comments_url'
''', returnStdout: true).trim()
  return commentOnPullRequest(comments_url, message)
}

// given a PR comments_url like https://api.github.com/repos/redhat-developer/devspaces/issues/848/comments
// publish a message containing links to build console/changes, or the currentBuild.description
// return comments_url (with comment hash) so we can pass that to downstream jobs
String commentOnPullRequest(String comments_url, String message) {
  // if url and message are set; otherwise return nullstring
  if (comments_url?.trim() && message?.trim()) {
    // convert html PR URL to API comment URL
    comments_url = comments_url.replaceAll("https://github.com/","https://api.github.com/repos/")
    comments_url = comments_url.replaceAll("/pull/([0-9]+)","/issues/\$1/comments")
    // fix relative job/build URLs to be absolute
    // TODO do we have to add suport for href="" and href='' ?
    message=message.replaceAll("<a href=/","<a href=${JENKINS_URL}")
    message=message.replaceAll("<a href=../","<a href="+currentBuild.absoluteUrl.replaceAll(".+/([^/]+/[0-9]+/*)",""))
    return sh(script: '''#!/bin/bash -xe
export GITHUB_TOKEN=''' + GITHUB_TOKEN + ''' # echo "''' + GITHUB_TOKEN + '''"
message="''' + message + '''"
comments_url="''' + comments_url + '''"

# comment on the PR by URL: https://api.github.com/repos/redhat-developer/devspaces/issues/848/comments
curl -sSL -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github.v3+json" -X POST \\
  -d '{"body": "'"${message}"'"}' "${comments_url}" | yq -r '.html_url'
''', returnStdout: true).trim()
  }
  return ""
}

// return this file's contents when loaded
return this
