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

def installYq() {
		sh '''#!/bin/bash -xe
sudo yum install -y -q jq python3-six python3-pip
sudo /usr/bin/python3 -m pip install -q --upgrade pip yq jsonschema; jq --version; yq --version
'''
}

def installRhpkg() {
  sh('''#!/bin/bash -xe
  sudo yum install -y -q yum-utils || true
  sudo yum-config-manager --add-repo http://download-node-02.eng.bos.redhat.com/rel-eng/RCMTOOLS/latest-RCMTOOLS-1-RHEL-8/compose/BaseOS/x86_64/os/ || true
  sudo yum install -y -q --nogpgcheck rhpkg krb5-workstation
  ''')
}

// to log into quay and RHEC, use this method where needed
def loginToRegistries() {
  withCredentials([
      string(credentialsId: 'quay.io-crw-crwci_user_token', variable: 'QUAY_TOKEN'),
      usernamePassword(credentialsId: 'registry.redhat.io_crw_bot', usernameVariable: 'CRW_BOT_USERNAME', passwordVariable: 'CRW_BOT_PASSWORD')
  ]){
    sh('''#!/bin/bash -xe
      PODMAN=$(command -v podman || true)
      if [[ ! -x $PODMAN ]]; then echo "[WARNING] podman is not installed."; PODMAN=$(command -v docker || true); fi
      if [[ ! -x $PODMAN ]]; then echo "[ERROR] docker is not installed. Aborting."; exit 1; fi
      echo "''' + QUAY_TOKEN + '''" | ${PODMAN} login -u="crw+crwci" --password-stdin quay.io
      echo "''' + CRW_BOT_PASSWORD + '''" | ${PODMAN} login -u="''' + CRW_BOT_USERNAME + '''" --password-stdin registry.redhat.io
      '''
    )
  }
}

// NEW WAY >= CRW 2.6, uses RHEC containerized skopeo build
// DOES NOT WORK on RHEL7: /lib64/libc.so.6: version `GLIBC_2.28' not found
def installSkopeoFromContainer(String container) {
  // default container to use - should be multiarch
  if (!container?.trim()) {
    container="registry.redhat.io/rhel8/skopeo"
  }
  withCredentials([usernamePassword(credentialsId: 'registry.redhat.io_crw_bot', usernameVariable: 'CRW_BOT_USERNAME', passwordVariable: 'CRW_BOT_PASSWORD')]){
    sh('''#!/bin/bash -xe
      sudo yum remove -y -q skopeo || true
      PODMAN=$(command -v podman || true)
      if [[ ! -x $PODMAN ]]; then echo "[WARNING] podman is not installed."; PODMAN=$(command -v docker || true); fi
      if [[ ! -x $PODMAN ]]; then echo "[ERROR] docker is not installed. Aborting."; exit 1; fi
      echo "''' + CRW_BOT_PASSWORD + '''" | ${PODMAN} login -u="''' + CRW_BOT_USERNAME + '''" --password-stdin registry.redhat.io
      ${PODMAN} run --rm -v /tmp:/skopeo registry.redhat.io/rhel8/skopeo sh -c "cp /usr/bin/skopeo /skopeo"; sudo cp -f /tmp/skopeo /usr/local/bin/skopeo; rm -f /tmp/skopeo || true
      skopeo --version
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
        credentialsId: 'devstudio-release',
        poll: true,
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
    ''' + updateBaseImages_bin + ''' -b ''' + BRANCH + ''' ''' + FLAGS
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

return this
