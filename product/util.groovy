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

// TODO https://issues.redhat.com/browse/CRW-360 - eventually we should use RH npm mirror
def installNPM(String nodeVersion, String yarnVersion) {
  USE_PUBLIC_NEXUS = true

  sh '''#!/bin/bash -e
export LATEST_NVM="$(git ls-remote --refs --tags https://github.com/nvm-sh/nvm.git \
          | cut --delimiter='/' --fields=3 | tr '-' '~'| sort --version-sort| tail --lines=1)"

export NODE_VERSION=''' + nodeVersion + '''
export METHOD=script
export PROFILE=/dev/null
curl -sSLo- https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST_NVM}/install.sh | bash
'''
  def nodeHome = sh(script: '''#!/bin/bash -e
source $HOME/.nvm/nvm.sh
nvm use --silent ''' + nodeVersion + '''
dirname $(nvm which node)''' , returnStdout: true).trim()
  env.PATH="${nodeHome}:${env.PATH}"
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

// For RHEL8 only; for RHEL7 assume podman or docker is already installed
def installPodman() {
  PODMAN = sh(script: '''#!/bin/bash -xe
  PODMAN="$(command -v podman || true)"
  if [[ ! -x $PODMAN ]]; then PODMAN="$(command -v docker || true)"; fi
  echo $PODMAN
  ''', returnStdout: true)
  if (PODMAN?.trim()) { // either podman or docker is already installed
    sh(script: '''#!/bin/bash -xe
      echo -n "[INFO] podman and/or docker is already installed: "
    ''' + PODMAN + ''' --version
  ''')
  } else {
    OS_IS_RHEL8 = sh(script: '''!#/bin/bash -xe
      grep -E '^VERSION=\"*8.' /etc/os-release
    ''', returnStdout: true)
    if (OS_IS_RHEL8?.trim()) {
      sh('''#!/bin/bash -xe
        echo "[INFO] Installing podman with docker emulation ..."
        sudo yum -y -q module install container-tools
      ''')
      installRPMs("fuse3 podman podman-docker")
      sh('''#!/bin/bash -xe
        # suppress message re: docker emulation w/ podman
        sudo touch /etc/containers/nodocker 
        podman --version
      ''')
    } else {
      sh('''#!/bin/bash -xe
        echo "[ERROR] RHEL 8 not detected: please install docker or podman manually to proceed."
        exit 1
      ''')
    }
  }
}

def installRPMs(String whichRPMs) {
  sh('''#!/bin/bash -xe
  # sudo yum install -y -q yum-utils || true # needed for yum-config-manager
  # sudo yum-config-manager -y -q --add-repo http://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-RHEL-8/compose/BaseOS/x86_64/os/ || true

  # insert multi-arch version, with gpgcheck disabled
  cat <<EOF | sudo tee /etc/yum.repos.d/latest-RCMTOOLS-2-RHEL-8.repo
[latest-RCMTOOLS-2-RHEL-8]
name=latest-RCMTOOLS-2-RHEL-8
baseurl=http://download.devel.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-2-RHEL-8/compose/BaseOS/\\$basearch/os/
enabled=1
gpgcheck=0
skip_if_unavailable=True
EOF
  sudo yum install -y -q ''' + whichRPMs + '''
  ''')
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
      ''', returnStatus:true
    )
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
          if [[ ! -z "$(cat /etc/os-release | grep -E '^VERSION=\"*8.')" ]]; then # RHEL 8
            echo "[INFO] $3 version $2 installed is < $1, will attempt to install latest from ''' + container + ''' ..."
            installFromContainer $3
          elif [[ ! -z "$(cat /etc/os-release | grep -E '^VERSION=\"*7.')" ]]; then # RHEL 7
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
  sh('''#!/bin/bash -xe
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
  )
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
        git config --global push.default matching'''
    )
  }
}

def updateBaseImages(String REPO_PATH, String BRANCH, String FLAGS="") {
  // Requires installSkopeo()
  def String updateBaseImages_bin="${WORKSPACE}/updateBaseImages.sh"
  if (!fileExists(updateBaseImages_bin)) {
    if (CRW_BRANCH_F.equals("")) {
      println("ERROR: execute getCrwVersion() before calling updateBaseImages")
      exit 1
    }
    sh('''#!/bin/bash -xe
      curl -L -s -S https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/''' + CRW_BRANCH_F + '''/product/updateBaseImages.sh -o ''' + updateBaseImages_bin + '''
      chmod +x ''' + updateBaseImages_bin
    )
  }
  sh('''#!/bin/bash -xe
    cd ''' + REPO_PATH + '''
    export GITHUB_TOKEN=''' + GITHUB_TOKEN + ''' # echo "''' + GITHUB_TOKEN + '''"
    export KRB5CCNAME=/var/tmp/crw-build_ccache
    ''' + updateBaseImages_bin + ''' -b ''' + BRANCH + ''' ''' + FLAGS + ''' || true'''
  )
}

def getLastCommitSHA(String REPO_PATH) {
  return sh(script: '''#!/bin/bash -xe
    cd ''' + REPO_PATH + '''
    git rev-parse HEAD''', returnStdout: true)
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
