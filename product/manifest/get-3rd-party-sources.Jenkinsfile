#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// CSV_VERSION = 2.2.0
// getLatestImageTagsFlags="--crw23" # placeholder for flag to pass to getLatestImageTags.sh

def buildNode = "rhel7-releng" // slave label

timeout(20) {
    node("${buildNode}"){
        // check out che-theia before we need it in build.sh so we can use it as a poll basis
        // then discard this folder as we need to check them out and massage them for crw
        stage "Collect 3rd party sources"
        cleanWs()
	      withCredentials([string(credentialsId:'devstudio-release.token', variable: 'GITHUB_TOKEN'), 
          file(credentialsId: 'crw-build.keytab', variable: 'CRW_KEYTAB')]) {
          checkout([$class: 'GitSCM', 
            branches: [[name: "master"]], 
            doGenerateSubmoduleConfigurations: false, 
            poll: true,
            extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "crw"]], 
            submoduleCfg: [], 
            userRemoteConfigs: [[url: "https://github.com/redhat-developer/codeready-workspaces.git"]]])

            sh '''#!/bin/bash -xe

# bootstrapping: if keytab is lost, upload to 
# https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/credentials/store/system/domain/_/
# then set Use secret text above and set Bindings > Variable (path to the file) as ''' + CRW_KEYTAB + '''
chmod 700 ''' + CRW_KEYTAB + ''' && chown ''' + USER + ''' ''' + CRW_KEYTAB + '''
# create .k5login file
echo "crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@REDHAT.COM" > ~/.k5login
chmod 644 ~/.k5login && chown ''' + USER + ''' ~/.k5login
echo "pkgs.devel.redhat.com,10.19.208.80 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAplqWKs26qsoaTxvWn3DFcdbiBxqRLhFngGiMYhbudnAj4li9/VwAJqLm1M6YfjOoJrj9dlmuXhNzkSzvyoQODaRgsjCG5FaRjuN8CSM/y+glgCYsWX1HFZSnAasLDuW0ifNLPR2RBkmWx61QKq+TxFDjASBbBywtupJcCsA5ktkjLILS+1eWndPJeSUJiOtzhoN8KIigkYveHSetnxauxv1abqwQTk5PmxRgRt20kZEFSRqZOJUlcl85sZYzNC/G7mneptJtHlcNrPgImuOdus5CW+7W49Z/1xqqWI/iRjwipgEMGusPMlSzdxDX4JzIx6R53pDpAwSAQVGDz4F9eQ==
rcm-guest.app.eng.bos.redhat.com,10.16.101.129 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEApd6cnyFVRnS2EFf4qeNvav0o+xwd7g7AYeR9dxzJmCR3nSoVHA4Q/kV0qvWkyuslvdA41wziMgSpwq6H/DPLt41RPGDgJ5iGB5/EDo3HAKfnFmVAXzYUrJSrYd25A1eUDYHLeObtcL/sC/5bGPp/0deohUxLtgyLya4NjZoYPQY8vZE6fW56/CTyTdCEWohDRUqX76sgKlVBkYVbZ3uj92GZ9M88NgdlZk74lOsy5QiMJsFQ6cpNw+IPW3MBCd5NHVYFv/nbA3cTJHy25akvAwzk8Oi3o9Vo0Z4PSs2SsD9K9+UvCfP1TUTI4PXS8WpJV6cxknprk0PSIkDdNODzjw==
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
kinit "crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@REDHAT.COM" -kt ''' + CRW_KEYTAB + '''
klist # verify working

# generate source files
cd ${WORKSPACE}/crw/product/manifest/ && ./get-3rd-party-sources.sh --clean ''' + getLatestImageTagsFlags + '''

# set up sshfs mount
DESTHOST="crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@rcm-guest.app.eng.bos.redhat.com"
RCMG="${DESTHOST}:/mnt/rcm-guest/staging/crw"
sshfs --version
for mnt in RCMG; do 
  mkdir -p ${WORKSPACE}/${mnt}-ssh; 
  if [[ $(file ${WORKSPACE}/${mnt}-ssh 2>&1) == *"Transport endpoint is not connected"* ]]; then fusermount -uz ${WORKSPACE}/${mnt}-ssh; fi
  if [[ ! -d ${WORKSPACE}/${mnt}-ssh/crw ]]; then  sshfs ${!mnt} ${WORKSPACE}/${mnt}-ssh; fi
done

# copy files to rcm-guest
ssh "${DESTHOST}" "cd /mnt/rcm-guest/staging/crw && mkdir -p CRW-''' + CSV_VERSION + '''/sources/containers CRW-''' + CSV_VERSION + '''/sources/vscode && ls -la . "
rsync -zrlt --rsh=ssh --protocol=28 ${WORKSPACE}/manifest-srcs.txt  ${WORKSPACE}/${mnt}-ssh/CRW-''' + CSV_VERSION + '''/sources/
rsync -zrlt --rsh=ssh --protocol=28  --delete ${WORKSPACE}/sources/containers/* ${WORKSPACE}/${mnt}-ssh/CRW-''' + CSV_VERSION + '''/sources/containers/
rsync -zrlt --rsh=ssh --protocol=28  --delete ${WORKSPACE}/sources/vscode/*     ${WORKSPACE}/${mnt}-ssh/CRW-''' + CSV_VERSION + '''/sources/vscode/
ssh "${DESTHOST}" "cd /mnt/rcm-guest/staging/crw/CRW-''' + CSV_VERSION + '''/ && tree"
ssh "${DESTHOST}" "/mnt/redhat/scripts/rel-eng/utility/bus-clients/stage-mw-release CRW-''' + CSV_VERSION + '''"
'''
          }
    }
}