#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// CSV_VERSION = 2.2.0
// getLatestImageTagsFlags="--crw23" # placeholder for flag to pass to getLatestImageTags.sh

def buildNode = "rhel7-releng" // node label

def MVN_FLAGS="-Dmaven.repo.local=.repository/ -V -B -e"

def buildMaven(){
	def mvnHome = tool 'maven-3.5.4'
	env.PATH="${env.PATH}:${mvnHome}/bin"
}

timeout(20) {
    node("${buildNode}"){
        // check out che-theia before we need it in build.sh so we can use it as a poll basis
        // then discard this folder as we need to check them out and massage them for crw
        stage "Collect 3rd party sources"
    	  wrap([$class: 'TimestamperBuildWrapper']) {
          cleanWs()
          buildMaven()
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
# install yq, python w/ virtualenv, pip, golang, nodejs, npm
sudo yum -y install jq python3-six python3-pip python-virtualenv-api python-virtualenv-clone python-virtualenvwrapper python36-virtualenv \
  golang nodejs npm epel-release
sudo /usr/bin/python3 -m pip install --upgrade pip yq

# instal php 7.3 for RHEL 7 via EPEL and remi
sudo yum -y -q remove php; sudo rm -fr /usr/bin/php /usr/bin/php-cgi
sudo yum -y -q install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm || true
sudo yum -y -q install http://rpms.remirepo.net/enterprise/remi-release-7.rpm || true
sudo yum -y -q install yum-utils
sudo subscription-manager repos --enable=rhel-7-server-optional-rpms || true
sudo yum-config-manager -y -q --disable remi-php54 || true
sudo yum-config-manager -y -q --enable remi-php73 || true
sudo yum -y -q install php73 php73-php php73-php-cli
sudo ln -s /usr/bin/php73 /usr/bin/php || true
sudo ln -s /usr/bin/php73-cgi /usr/bin/php-cgi || true

echo "-----"
jq --version; echo "-----"
python --version; echo "-----"
go version; echo "-----"
echo -n "node "; node --version; echo "-----"
echo -n "npm "; npm --version; echo "-----"
php --version; echo "-----"

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
cd ${WORKSPACE}/crw/product/manifest/ && ./get-3rd-party-deps-manifests.sh ''' + getLatestImageTagsFlags + '''

# copy over the dir contents
rsync -azrlt ${WORKSPACE}/''' + CSV_VERSION + '''/* ${WORKSPACE}/crw/product/manifest/''' + CSV_VERSION + '''/
# sync the directory and delete from target if deleted from source
rsync -azrlt --delete ${WORKSPACE}/''' + CSV_VERSION + '''/ ${WORKSPACE}/crw/product/manifest/''' + CSV_VERSION + '''/
tree ${WORKSPACE}/crw/product/manifest/''' + CSV_VERSION + '''

# commit manifest files
git checkout --track origin/master || true
export GITHUB_TOKEN=''' + GITHUB_TOKEN + ''' # echo "''' + GITHUB_TOKEN + '''"
git config user.email "nickboldt+devstudio-release@gmail.com"
git config user.name "Red Hat Devstudio Release Bot"
git config --global push.default matching

# SOLVED :: Fatal: Could not read Username for "https://github.com", No such device or address :: https://github.com/github/hub/issues/1644
git remote -v
git config --global hub.protocol https
git remote set-url origin https://\$GITHUB_TOKEN:x-oauth-basic@github.com/redhat-developer/codeready-workspaces.git
git remote -v

git add ''' + CSV_VERSION + '''
git commit -s -m "[prodsec] Update product security manifests for ''' + CSV_VERSION + '''" ''' + CSV_VERSION + '''
git push origin master

'''
          }
        }
    }
}