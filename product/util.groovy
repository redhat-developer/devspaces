import groovy.transform.Field

@Field String CSV_VERSION_F = ""
def String getCSVVersion(String MIDSTM_BRANCH) {
  if (CSV_VERSION_F.equals("")) {
    CSV_VERSION_F = sh(script: '''#!/bin/bash -xe
    curl -sSLo- https://raw.githubusercontent.com/redhat-developer/codeready-workspaces-operator/''' + MIDSTM_BRANCH + '''/manifests/codeready-workspaces.csv.yaml | yq -r .spec.version''', returnStdout: true).trim()
  }
  return CSV_VERSION_F
}

@Field String CRW_VERSION_F = ""
@Field String CRW_BRANCH_F = ""
def String getCrwVersion(String MIDSTM_BRANCH) {
  if (CRW_VERSION_F.equals("")) {
    CRW_BRANCH_F = MIDSTM_BRANCH
    CRW_VERSION_F = sh(script: '''#!/bin/bash -xe
    curl -sSLo- https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/''' + MIDSTM_BRANCH + '''/dependencies/VERSION''', returnStdout: true).trim()
  }
  return CRW_VERSION_F
}

def installMaven(String MAVEN_VERSION, String JAVA_VERSION){
  mURL="https://www.apache.org/dyn/mirrors/mirrors.cgi?action=download&filename=maven/maven-3/" + MAVEN_VERSION + "/binaries/apache-maven-" + MAVEN_VERSION + "-bin.tar.gz"
  sh('''#!/bin/bash -xe
    if [[ ! -x /opt/apache-maven/bin/mvn ]]; then 
        cd /tmp; curl -sSLO "''' + mURL + '''"
        rm -fr /opt/apache-maven /opt/apache-maven-*-bin.tar.gz
        mkdir -p /opt && sudo tar xzf /tmp/apache-maven-''' + MAVEN_VERSION + '''-bin.tar.gz -C /opt && sudo mv /opt/apache-maven-''' + MAVEN_VERSION + ''' /opt/apache-maven
        # fix permissions in bin/* files \
        for d in $(find /opt/apache-maven -name bin -type d); do echo $d; sudo chmod +x $d/*; done
        rm -fr /opt/apache-maven-*-bin.tar.gz
    else
      /opt/apache-maven/bin/mvn -v
    fi
  ''')
  env.PATH="/usr/lib/jvm/java-"+JAVA_VERSION+"-openjdk:/opt/apache-maven/bin:/usr/bin:${env.PATH}"
  env.JAVA_HOME="/usr/lib/jvm/java-"+JAVA_VERSION+"-openjdk"
  env.M2_HOME="/opt/apache-maven" 
  sh ("mvn -v")
}

// TODO https://issues.redhat.com/browse/CRW-360 - eventually we should use RH npm mirror
def installNPM(String nodeVersion, String yarnVersion) {
  installNPM(nodeVersion, yarnVersion, false)
}
def installNPM(String nodeVersion, String yarnVersion, boolean installP7zip) {
  USE_PUBLIC_NEXUS = true

  sh '''#!/bin/bash -e
export LATEST_NVM="$(git ls-remote --refs --tags https://github.com/nvm-sh/nvm.git \
  | cut --delimiter='/' --fields=3 | tr '-' '~'| sort --version-sort| tail --lines=1)"

export NODE_VERSION=''' + nodeVersion + '''
export METHOD=script
export PROFILE=/dev/null
curl -sSLo- https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST_NVM}/install.sh | bash

# nvm post-install recommendation
echo '
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"  # This loads nvm
' >> ${HOME}/.bashrc
'''
  def nodeHome = sh(script: '''#!/bin/bash -e
source $HOME/.nvm/nvm.sh
nvm use --silent ''' + nodeVersion + '''
dirname $(nvm which node)''' , returnStdout: true).trim()
  env.PATH="${nodeHome}:${env.PATH}"

  // used by crwctl build
  if (installP7zip) {
    installRPMs("p7zip")
    sh '''#!/bin/bash -xe
# remove windows 7z if installed; link to rpm-installed p7zip instead 
rm -fr ''' + nodeHome + '''/lib/node_modules/7zip; 
if [[ -x /usr/bin/7za ]]; then pushd ''' + nodeHome + ''' >/dev/null; sudo rm -f 7z*; sudo ln -s /usr/bin/7za 7z; popd >/dev/null; fi
''' + nodeHome + '''/7z | grep -i version
/usr/bin/7za | grep -i version
'''
  }

  sh '''#!/bin/bash -xe
rm -f ${HOME}/.npmrc ${HOME}/.yarnrc
npm install --global yarn@''' + yarnVersion + '''
node --version && npm --version; yarn --version
'''

  sh "echo USE_PUBLIC_NEXUS = ${USE_PUBLIC_NEXUS}"
  if (!USE_PUBLIC_NEXUS) {
      sh '''#!/bin/bash -xe
echo '
registry=https://repository.engineering.redhat.com/nexus/repository/registry.npmjs.org/
cafile=/etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt
strict-ssl=false
virtual/:_authToken=credentials
always-auth=true
' > ${HOME}/.npmrc

echo '
# registry "https://repository.engineering.redhat.com/nexus/repository/registry.npmjs.org/"
registry "https://registry.yarnpkg.com"
cafile /etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt
strict-ssl false
' > ${HOME}/.yarnrc

cat ${HOME}/.npmrc
cat ${HOME}/.yarnrc

npm install --global yarn@''' + yarnVersion + '''
npm config get; yarn config get list
npm --version; yarn --version
'''
  }
  else
  {
        sh '''#!/bin/bash -xe
rm -f ${HOME}/.npmrc ${HOME}/.yarnrc
npm install --global yarn@''' + yarnVersion + '''
node --version; npm --version; yarn --version
'''
  }
}

def installYq() {
  installRPMs("jq python3-six python3-pip")
  sh('''#!/bin/bash -xe
sudo /usr/bin/python3 -m pip install -q --upgrade pip yq jsonschema; jq --version; yq --version
  ''')
}
def installBrewKoji() {
  installRPMs("brewkoji")
}
def installRhpkg() {
  installRPMs("rhpkg krb5-workstation")
}
def installSshfs() {
  // provides shasum for oclif-dev; need fuse-sshfs for mounting drive to copy to rcm-guest
  installRPMs("perl-Digest-SHA fuse-sshfs", true)
}
def installPodman2() {
  updatePodman(true)
}

// install podman from latest pulp repos, >=2.0.5
def updatePodman(boolean usePulpRepos=true) {
  if (usePulpRepos) { enablePulpRepos() }
  sh('''#!/bin/bash -xe
echo "[INFO] Installing podman with docker emulation ..."
sudo yum -y -q module install container-tools
  ''')
  installRPMs("fuse3 podman podman-docker")
  sh('''#!/bin/bash -xe
sudo yum update -y -q fuse3 podman podman-docker || true

# suppress message re: docker emulation w/ podman
sudo touch /etc/containers/nodocker
podman --version
  ''')
}

// For RHEL8 only; for RHEL7 assume podman or docker is already installed
// if already installed, don't reinstall
def installPodman(boolean usePulpRepos=false) {
  PODMAN = sh(script: '''#!/bin/bash -e
  PODMAN="$(command -v podman || true)"
  if [[ ! -x $PODMAN ]]; then PODMAN="$(command -v docker || true)"; fi
  echo "$PODMAN"''', returnStdout: true).trim()
  if (PODMAN?.trim()) { // either podman or docker is already installed
    sh(script: '''#!/bin/bash -xe
      PODMAN_VERSION="$(''' + PODMAN + ''' --version | awk '{ print $3 }')"
      echo "[INFO] podman and/or docker present as ''' + PODMAN + ''', version ${PODMAN_VERSION}"
  ''')
  } else {
    OS_IS_RHEL8 = sh(script: '''#!/bin/bash -xe
      grep -E '^VERSION=\"*8.' /etc/os-release || true
    ''', returnStdout: true)
    if (OS_IS_RHEL8?.trim()) {
      updatePodman(usePulpRepos)
    } else {
      sh('''#!/bin/bash -xe
        echo "[ERROR] RHEL 8 not detected: please install docker or podman manually to proceed."
        exit 1
      ''')
    }
  }
}

// rcmtools repo required for rhpkg and kinit
def enableRcmToolsRepo() {
  sh '''#!/bin/bash -xe
# rather than creating .repo files, could shortcut using yum-utils, but
# this creates single-arch .repo files with gpg enabled and no skip_if_unavailable=True
# sudo yum install -y -q yum-utils || true # needed for yum-config-manager
# sudo yum-config-manager -y -q --add-repo http://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-RHEL-8/compose/BaseOS/x86_64/os/ || true

# use multi-arch repo, with gpgcheck disabled
repo=latest-RCMTOOLS-2-RHEL-8
cat <<EOF | sudo tee /etc/yum.repos.d/${repo}.repo
[${repo}]
name=${repo}
baseurl=http://download.devel.redhat.com/rel-eng/RCMTOOLS/${repo}/compose/BaseOS/\\$basearch/os/
enabled=1
gpgcheck=0
skip_if_unavailable=True
EOF
'''
}

// rhel8-8-codeready-builder repo required fuse-sshfs (to push release bits/sources to rcm-guest)
// rhel8-8-appstream repo required for podman >=2.0.5 (includes --override-arch) and skopeo >=1.1
def enablePulpRepos() {
  sh '''#!/bin/bash -xe
# use multi-arch repos, with gpgcheck disabled
repo=rhocp-4.6
cat <<EOF | sudo tee /etc/yum.repos.d/${repo}-pulp.repo
[${repo}]
name=${repo}
baseurl=http://pulp.dist.prod.ext.phx2.redhat.com/content/dist/layered/rhel8/\\$basearch/${repo/-/\\/}/os/
enabled=1
gpgcheck=0
skip_if_unavailable=True
EOF

# enable rhel8 pulp repos to resolve newer dependencies; use multi-arch repo, with gpgcheck disabled
repo=rhel8-8
cat <<EOF | sudo tee /etc/yum.repos.d/${repo}-pulp.repo
[${repo}-appstream]
name=${repo}-appstream
baseurl=http://pulp.dist.prod.ext.phx2.redhat.com/content/dist/${repo/-/\\/}/\\$basearch/appstream/os
enabled=1
gpgcheck=0
skip_if_unavailable=True

[${repo}-baseos]
name=${repo}-baseos
baseurl=http://pulp.dist.prod.ext.phx2.redhat.com/content/dist/${repo/-/\\/}/\\$basearch/baseos/os
enabled=1
gpgcheck=0
skip_if_unavailable=True

[${repo}-codeready-builder]
name=${repo}-codeready-builder
baseurl=http://pulp.dist.prod.ext.phx2.redhat.com/content/dist/${repo/-/\\/}/\\$basearch/codeready-builder/os
enabled=1
gpgcheck=0
skip_if_unavailable=True
EOF
'''
}

// sudo must already be installed and user must be a sudoer
def installRPMs(String whichRPMs, boolean usePulpRepos=false) {
  enableRcmToolsRepo()
  if (usePulpRepos) { enablePulpRepos() }
  sh '''#!/bin/bash -xe
sudo yum install -y -q ''' + whichRPMs + '''
'''
}

// to log into dockerhub, quay and RHEC, use this method where needed
// if process fails, return code marking failure
def loginToRegistries() {
  withCredentials([
      usernamePassword(credentialsId: 'che_dockerhub-user-password', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_PASSWORD'),
      string(credentialsId: 'quay.io-crw-crwci_user_token', variable: 'QUAY_TOKEN'),
      usernamePassword(credentialsId: 'registry.redhat.io_crw_bot', usernameVariable: 'CRW_BOT_USERNAME', passwordVariable: 'CRW_BOT_PASSWORD')
  ]){
    return sh(script: '''#!/bin/bash -xe
PODMAN=$(command -v podman || true)
if [[ ! -x $PODMAN ]]; then echo "[WARNING] podman is not installed."; PODMAN=$(command -v docker || true); fi
if [[ ! -x $PODMAN ]]; then echo "[ERROR] docker is not installed. Aborting."; exit 1; fi
echo "''' + DOCKERHUB_PASSWORD + '''" | ${PODMAN} login -u="''' + DOCKERHUB_USERNAME + '''" --password-stdin docker.io
echo "''' + QUAY_TOKEN + '''" | ${PODMAN} login -u="crw+crwci" --password-stdin quay.io
echo "''' + CRW_BOT_PASSWORD + '''" | ${PODMAN} login -u="''' + CRW_BOT_USERNAME + '''" --password-stdin registry.redhat.io
    ''', returnStatus:true)
  }
}

// NEW WAY >= CRW 2.6, uses RHEC containerized skopeo build
// DOES NOT WORK on RHEL7: /lib64/libc.so.6: version `GLIBC_2.28' not found, so fall back to old way from CRW 2.5 Jenkins if Skopeo not installed on RHEL7 node
def installSkopeoFromContainer(String container) {
  if (!container?.trim()) {
    container="registry.redhat.io/rhel8/skopeo"
  }
  installSkopeoFromContainer(container,"1.1")
}

// note that SElinux needs to be permissive or disabled to volume mount a container to extract file(s)
def installSkopeoFromContainer(String container, String minimumVersion) {
  // default container to use - should be multiarch
  if (!container?.trim()) {
    container="registry.redhat.io/rhel8/skopeo"
  }
  if (!minimumVersion?.trim()) {
    minimumVersion="1.1"
  }
  withCredentials([usernamePassword(credentialsId: 'registry.redhat.io_crw_bot', usernameVariable: 'CRW_BOT_USERNAME', passwordVariable: 'CRW_BOT_PASSWORD')]){
    sh('''#!/bin/bash -xe

      # NEW WAY >= CRW 2.6, uses RHEC containerized skopeo build, requires RHEL 8 worker node
      installFromContainer()
      {
        installable="$1"
        sudo yum remove -y -q ${installable} || true
        PODMAN=$(command -v podman || true)
        if [[ ! -x $PODMAN ]]; then echo "[WARNING] podman is not installed."; PODMAN=$(command -v docker || true); fi
        if [[ ! -x $PODMAN ]]; then echo "[ERROR] docker is not installed. Aborting."; exit 1; fi
        echo "''' + CRW_BOT_PASSWORD + '''" | ${PODMAN} login -u="''' + CRW_BOT_USERNAME + '''" --password-stdin registry.redhat.io
        ${PODMAN} run --rm -v /tmp:/${installable} ''' + container + ''' sh -c "cp /usr/bin/${installable} /${installable}"; sudo cp -f /tmp/${installable} /usr/local/bin/${installable}; rm -f /tmp/${installable} || true
        sudo chmod 755 /usr/local/bin/${installable}
        ${installable} --version
      }

      # OLD WAY, <= CRW 2.5 and for RHEL 7 worker nodes (including Beaker)
      installFromTarball()
      {
        CRW_VERSION="$1"
        jenkinsURL="https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/crw-deprecated_${CRW_VERSION}/lastSuccessfulBuild/artifact/codeready-workspaces-deprecated/skopeo/target"
        pushd /tmp >/dev/null
        # remove any older versions
        sudo yum remove -y -q skopeo || true
        if [[ ! -x /usr/local/bin/skopeo ]]; then
          sudo curl -sSLO "${jenkinsURL}/skopeo-$(uname -m).tar.gz"
        fi
        if [[ -f /tmp/skopeo-$(uname -m).tar.gz ]]; then
          sudo tar xzf /tmp/skopeo-$(uname -m).tar.gz --overwrite -C /usr/local/bin/
          sudo chmod 755 /usr/local/bin/skopeo
          sudo rm -f /tmp/skopeo-$(uname -m).tar.gz
        fi
        popd >/dev/null
        skopeo --version
      }

      checkVersion() {
        if [[  "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]]; then
          echo "[INFO] $3 version $2 installed is >= $1, can proceed."
        else
          if [[ ! -z "$(cat /etc/os-release | grep -E '^VERSION=\"*8.' || true)" ]]; then # RHEL 8
            echo "[INFO] $3 version $2 installed is < $1, will attempt to install latest from ''' + container + ''' ..."
            installFromContainer $3
          elif [[ ! -z "$(cat /etc/os-release | grep -E '^VERSION=\"*7.' || true)" ]]; then # RHEL 7
            echo "[INFO] $3 version $2 installed is < $1, will attempt to install latest from ${jenkinsURL}/skopeo-$(uname -m).tar.gz ..."
            installFromTarball 2.5
          else
            echo "[ERROR] Cannot determine which version of RHEL is currently running. Please install ${installable} manually to proceed."
            exit 1
          fi
        fi
      }

      SKOPEO_VERSION=""
      if [ ! -z "$(which skopeo)" ] ; then
        SKOPEO_VERSION="$(skopeo -v 2> /dev/null | awk '{ print $3 }')"
      fi
      checkVersion ''' + minimumVersion + ''' "${SKOPEO_VERSION}" skopeo
      '''
    )
  }
}

// OLD WAY <= CRW 2.5, uses version built in Jenkins from latest sources
def installSkopeo(String CRW_VERSION) {
  sh '''#!/bin/bash -xe
pushd /tmp >/dev/null
# remove any older versions
sudo yum remove -y -q skopeo || true
if [[ ! -x /usr/local/bin/skopeo ]]; then
  sudo curl -sSLO "https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/crw-deprecated_''' + CRW_VERSION + '''/lastSuccessfulBuild/artifact/codeready-workspaces-deprecated/skopeo/target/skopeo-$(uname -m).tar.gz"
fi
if [[ -f /tmp/skopeo-$(uname -m).tar.gz ]]; then
  sudo tar xzf /tmp/skopeo-$(uname -m).tar.gz --overwrite -C /usr/local/bin/
  sudo chmod 755 /usr/local/bin/skopeo
  sudo rm -f /tmp/skopeo-$(uname -m).tar.gz
fi
popd >/dev/null
skopeo --version
'''
}

def cloneRepo(String URL, String REPO_PATH, String BRANCH) {
  // Requires withCredentials() and bootstrap()
  if (URL.indexOf("pkgs.devel.redhat.com") == -1) {
    // remove http(s) prefix, then trim any token@ prefix too
    URL=URL - ~/http(s*):\/\// - ~/.*@/
    def AUTH_URL_SHELL="https://\$GITHUB_TOKEN:x-oauth-basic@" + URL
    def AUTH_URL_GROOVY="https://$GITHUB_TOKEN:x-oauth-basic@" + URL
    if (!fileExists(REPO_PATH)) {
      checkout([$class: 'GitSCM',
        branches: [[name: BRANCH]],
        doGenerateSubmoduleConfigurations: false,
        extensions: [
          [$class: 'RelativeTargetDirectory', relativeTargetDir: REPO_PATH],
          [$class: 'DisableRemotePoll']
        ],
        submoduleCfg: [],
        userRemoteConfigs: [[url: AUTH_URL_GROOVY]]])
    }
    sh('''#!/bin/bash -xe
cd ''' + REPO_PATH + '''
git checkout --track origin/''' + BRANCH + ''' || true
export GITHUB_TOKEN=''' + GITHUB_TOKEN + ''' # echo "''' + GITHUB_TOKEN + '''"
git config user.email "nickboldt+devstudio-release@gmail.com"
git config user.name "Red Hat Devstudio Release Bot"
git config --global push.default matching
# SOLVED :: Fatal: Could not read Username for "https://github.com", No such device or address :: https://github.com/github/hub/issues/1644
git config --global hub.protocol https
git remote set-url origin ''' + AUTH_URL_SHELL
    )
  } else {
    if (!fileExists(REPO_PATH)) {
      sh('''#!/bin/bash -xe
export KRB5CCNAME=/var/tmp/crw-build_ccache
git clone ''' + URL + ''' ''' + REPO_PATH
      )
    }
    sh('''#!/bin/bash -xe
export KRB5CCNAME=/var/tmp/crw-build_ccache
cd ''' + REPO_PATH + '''
git checkout --track origin/''' + BRANCH + ''' || true
git config user.email crw-build@REDHAT.COM
git config user.name "CRW Build"
git config --global push.default matching
'''
    )
  }
}

// Requires installSkopeo*() and installYq() to run
// Requires getCrwVersion() to set CRW_BRANCH_F in order to install correct version of the script; or, if JOB_BRANCH is defined by .groovy param or in .jenkinsfile, will use that version
def updateBaseImages(String REPO_PATH, String SOURCES_BRANCH, String FLAGS="", String SCRIPTS_BRANCH="") {
  def String updateBaseImages_bin="${WORKSPACE}/updateBaseImages.sh"
  if (SOURCES_BRANCH?.trim() && !CRW_BRANCH_F?.trim()) {
    getCrwVersion(SOURCES_BRANCH)
  }
  if (!SCRIPTS_BRANCH?.trim() && CRW_BRANCH_F?.trim()) {
    SCRIPTS_BRANCH = CRW_BRANCH_F // this should work for midstream/downstream branches like crw-2.6-rhel-8
  } else if (!SCRIPTS_BRANCH?.trim() && MIDSTM_BRANCH?.trim()) {
    SCRIPTS_BRANCH = MIDSTM_BRANCH // this should work for midstream/downstream branches like crw-2.6-rhel-8
  } else if (!SCRIPTS_BRANCH?.trim() && JOB_BRANCH?.trim()) {
    SCRIPTS_BRANCH = JOB_BRANCH // this might fail if the JOB_BRANCH is 2.6 and there's no such branch
  }
  // fail build if not true
  assert (CRW_BRANCH_F?.trim()) : "ERROR: execute getCrwVersion() before calling updateBaseImages()"

  if (!fileExists(updateBaseImages_bin)) {
    // otherwise continue
    sh('''#!/bin/bash -xe
URL="https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/''' + SCRIPTS_BRANCH + '''/product/updateBaseImages.sh"
# check for 404 and fail if can't load the file
header404="$(curl -sSLI $URL | grep -E -v "id: |^x-" | grep -E "404|Not Found" || true)"
if [[ $header404 ]]; then
  echo "[ERROR] Can not resolved $URL : $header404 "
  echo "[ERROR] Please check the value of SCRIPTS_BRANCH = ''' + SCRIPTS_BRANCH + ''' to confirm it's a valid branch."
  exit 1
else
  curl -sSL $URL -o ''' + updateBaseImages_bin + ''' && chmod +x ''' + updateBaseImages_bin + '''
fi
    ''')
  }
  // NOTE: b = sources branch, sb = scripts branch
  // TODO CRW-1511 sometimes updateBaseImages gets a 404 instead of a valid script for getLatestImageTags. Why? 
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
export KRB5CCNAME="/var/tmp/crw-build_ccache"
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

def getLastCommitSHA(String REPO_PATH) {
  return sh(script: '''#!/bin/bash -xe
    cd ''' + REPO_PATH + '''
    git rev-parse --short=4 HEAD''', returnStdout: true).trim()
}

def getCRWLongName(String SHORT_NAME) {
  if (SHORT_NAME == "server") {
    return "codeready-workspaces"
  }
  return "codeready-workspaces-" + SHORT_NAME
}

def getCRWShortName(String LONG_NAME) {
  if (LONG_NAME == "codeready-workspaces") {
    return "server"
  }
  return LONG_NAME.minus("codeready-workspaces-")
}

def bootstrap(String CRW_KEYTAB) {
  // rpm -qf $(which kinit ssh-keyscan chmod) ==> krb5-workstation openssh-clients coreutils
  installRPMs("krb5-workstation openssh-clients coreutils")
  sh('''#!/bin/bash -xe
# bootstrapping: if keytab is lost, upload to
# https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/credentials/store/system/domain/_/
# then set Use secret text above and set Bindings > Variable (path to the file) as ''' + CRW_KEYTAB + '''
chmod 700 ''' + CRW_KEYTAB + ''' && chown ''' + USER + ''' ''' + CRW_KEYTAB + '''
# create .k5login file
echo "crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@REDHAT.COM" > ~/.k5login
chmod 644 ~/.k5login && chown ''' + USER + ''' ~/.k5login
echo "pkgs.devel.redhat.com,10.19.208.80 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAplqWKs26qsoaTxvWn3DFcdbiBxqRLhFngGiMYhbudnAj4li9/VwAJqLm1M6YfjOoJrj9dlmuXhNzkSzvyoQODaRgsjCG5FaRjuN8CSM/y+glgCYsWX1HFZSnAasLDuW0ifNLPR2RBkmWx61QKq+TxFDjASBbBywtupJcCsA5ktkjLILS+1eWndPJeSUJiOtzhoN8KIigkYveHSetnxauxv1abqwQTk5PmxRgRt20kZEFSRqZOJUlcl85sZYzNC/G7mneptJtHlcNrPgImuOdus5CW+7W49Z/1xqqWI/iRjwipgEMGusPMlSzdxDX4JzIx6R53pDpAwSAQVGDz4F9eQ==
" >> ~/.ssh/known_hosts
ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
# see https://mojo.redhat.com/docs/DOC-1071739
if [[ -f ~/.ssh/config ]]; then mv -f ~/.ssh/config{,.BAK}; fi
echo "
GSSAPIAuthentication yes
GSSAPIDelegateCredentials yes
Host pkgs.devel.redhat.com
User crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@REDHAT.COM
" > ~/.ssh/config
chmod 600 ~/.ssh/config
# initialize kerberos
export KRB5CCNAME=/var/tmp/crw-build_ccache
# verify keytab is a valid file
# sudo klist -k ''' + CRW_KEYTAB + '''
kinit "crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@REDHAT.COM" -kt ''' + CRW_KEYTAB + '''
# verify keytab loaded
# klist
'''
  )

  // also install commonly needed tools
  installSkopeoFromContainer("")
  installYq()
  installRhpkg()
}

def notifyBuildFailed() {
    emailext (
        subject: "Build failed in Jenkins: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
        body: """
Build failed in Jenkins: ${env.JOB_NAME} #${env.BUILD_NUMBER}

Build:   ${env.BUILD_URL}
Steps:   ${env.BUILD_URL}/flowGraphTable

Params:  ${env.BUILD_URL}/parameters
Console: ${env.BUILD_URL}/console

Rebuild: ${env.BUILD_URL}/rebuild
""",
        recipientProviders: [culprits(), developers(), requestor()]
        // [$class: 'CulpritsRecipientProvider'],[$class: 'DevelopersRecipientProvider']]
    )
}

return this
