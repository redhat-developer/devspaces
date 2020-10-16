#!/usr/bin/env groovy

import groovy.transform.Field

// PARAMETERS for this pipeline:
// BUILDINFO = ${JOB_NAME}/${BUILD_NUMBER}
// SCRATCH = true (don't push to Quay) or false (do push to Quay)
// FORCE_BUILD = "false"

@Field String branchToBuildDev = "refs/tags/19"
@Field String branchToBuildParent = "refs/tags/7.15.0"
@Field String branchToBuildChe = "7.20.x"
@Field String MIDSTM_BRANCH = "crw-2.5-rhel-8" // target branch in GH repo, eg., crw-2.5-rhel-8

@Field String PUSH_TO_QUAY = "true"
@Field String MVN_EXTRA_FLAGS = "" // additional flags for maven (currently not used), eg., to disable a module -pl '!org.eclipse.che.selenium:che-selenium-test'

def DWNSTM_REPO = "containers/codeready-workspaces" // dist-git repo to use as target for everything
def DWNSTM_BRANCH = MIDSTM_BRANCH // target branch in dist-git repo, eg., crw-2.5-rhel-8

def installNPM(){
	def yarnVersion="1.21.0"
	def nodeHome = tool 'nodejs-10.19.0'
	env.PATH="${nodeHome}/bin:${env.PATH}"
	sh '''#!/bin/bash -xe
rm -f ${HOME}/.npmrc ${HOME}/.yarnrc
npm install --global yarn@''' + yarnVersion + '''
npm --version; yarn --version
'''
}
def installGo(){
	def goHome = tool 'go-1.10'
	env.PATH="${env.PATH}:${goHome}/bin"
	sh "go version"
}

def installYq(){
		sh '''#!/bin/bash -xe
sudo yum -y install jq python3-six python3-pip
sudo /usr/bin/python3 -m pip install --upgrade pip yq; jq --version; yq --version
'''
}

@Field String CRW_VERSION_F = ""
def String getCrwVersion(String MIDSTM_BRANCH) {
  if (CRW_VERSION_F.equals("")) {
    CRW_VERSION_F = sh(script: '''#!/bin/bash -xe
    curl -sSLo- https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/''' + MIDSTM_BRANCH + '''/dependencies/VERSION''', returnStdout: true).trim()
  }
  return CRW_VERSION_F
}

def installSkopeo(String CRW_VERSION)
{
sh '''#!/bin/bash -xe
pushd /tmp >/dev/null
# remove any older versions
sudo yum remove -y skopeo || true
# install from @kcrane build
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

def MVN_FLAGS="-Dmaven.repo.local=.repository/ -V -B -e"

def installMaven(){
	def mvnHome = tool 'maven-3.6.2'
	env.PATH="/qa/tools/opt/x86_64/openjdk11_last/bin:${env.PATH}:${mvnHome}/bin"
	sh "mvn -v"
}

def CRW_SHAs = ""

def DEV_path = "che-dev"
def VER_DEV = "VER_DEV"
def SHA_DEV = "SHA_DEV"

def PAR_path = "che-parent"
def VER_PAR = "VER_PAR"
def SHA_PAR = "SHA_PAR"

def CHE_DB_path = "che-dashboard"
def VER_CHE_DB = "VER_CHE_DB"
def SHA_CHE_DB = "SHA_CHE_DB"

def CHE_WL_path = "che-workspace-loader"
def VER_CHE_WL = "VER_CHE_WL"
def SHA_CHE_WL = "SHA_CHE_WL"

def CHE_path = "che"
def VER_CHE = "VER_CHE"
def VER_CHE_PREV = "VER_CHE_PREV"
def SHA_CHE = "SHA_CHE"

def CRW_path = "codeready-workspaces"
def VER_CRW = "VER_CRW"
def SHA_CRW = "SHA_CRW"

timeout(240) {
	node("rhel7-32gb||rhel7-16gb||rhel7-8gb"){ stage "Build ${DEV_path}, ${PAR_path}, ${CHE_DB_path}, ${CHE_WL_path}, and ${CRW_path}"
		wrap([$class: 'TimestamperBuildWrapper']) {
		    withCredentials([string(credentialsId:'devstudio-release.token', variable: 'GITHUB_TOKEN'), 
		    	file(credentialsId: 'crw-build.keytab', variable: 'CRW_KEYTAB')]) {
		cleanWs()
		installMaven()
		installNPM()
		installGo()
		installYq()
		CRW_VERSION = getCrwVersion(DWNSTM_BRANCH)
		println "CRW_VERSION = '" + CRW_VERSION + "'"
		installSkopeo(CRW_VERSION)

		echo "===== Build che-dev =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildDev}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${DEV_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${DEV_path}.git"]]])
		sh "mvn clean install ${MVN_FLAGS} -f ${DEV_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashDev', includes: findFiles(glob: '.repository/**').join(", ")

		VER_DEV = sh(returnStdout:true,script:"egrep \"<version>\" ${DEV_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_DEV = sh(returnStdout:true,script:"cd ${DEV_path}/ && git rev-parse --short=4 HEAD").trim()
		echo "<===== Build che-dev ====="

		echo "===== Build che-parent =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildParent}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${PAR_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${PAR_path}.git"]]])
		sh "mvn clean install ${MVN_FLAGS} -f ${PAR_path}/pom.xml ${MVN_EXTRA_FLAGS}"

		VER_PAR = sh(returnStdout:true,script:"egrep \"<version>\" ${PAR_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_PAR = sh(returnStdout:true,script:"cd ${PAR_path}/ && git rev-parse --short=4 HEAD").trim()
		echo "<===== Build che-parent ====="

		echo "===== Get CRW version =====>"
		if (env.ghprbPullId && env.ghprbPullId?.trim()) {
			checkout([$class: 'GitSCM', 
				branches: [[name: "FETCH_HEAD"]], 
				doGenerateSubmoduleConfigurations: false, 
				poll: true,
				extensions: [
					[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"],
					[$class: 'LocalBranch'],
					[$class: 'PathRestriction', excludedRegions: 'dependencies/**'],
					[$class: 'DisableRemotePoll']
				],
				submoduleCfg: [], 
				userRemoteConfigs: [[refspec: "+refs/pull/${env.ghprbPullId}/head:refs/remotes/origin/PR-${env.ghprbPullId}", url: "https://github.com/redhat-developer/codeready-workspaces.git"]]])
		} else {
			checkout([$class: 'GitSCM', 
				branches: [[name: "${MIDSTM_BRANCH}"]], 
				doGenerateSubmoduleConfigurations: false, 
				poll: true,
				extensions: [
					[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"],
					[$class: 'PathRestriction', excludedRegions: 'dependencies/**'],
				],
				submoduleCfg: [], 
				userRemoteConfigs: [[url: "https://github.com/redhat-developer/codeready-workspaces.git"]]])
		}
		VER_CRW = sh(returnStdout:true,script:"egrep \"<version>\" ${CRW_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CRW = sh(returnStdout:true,script:"cd ${CRW_path}/ && git rev-parse --short=4 HEAD").trim()
		echo "<===== Get CRW version ====="

		echo "===== Get Che version =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildChe}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CHE_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${CHE_path}.git"]]])

		VER_CHE = sh(returnStdout:true,script:'''#!/bin/bash -xe
egrep "<version>" ''' + CHE_path + '''/pom.xml|head -2|tail -1|sed -r -e "s#.*<version>(.+)</version>#\\1#"
''').trim()
		// for VERSION=7.18.3, get BASE=7.18, PREV=2 so VER_CHE_PREV=7.18.2
		VER_CHE_PREV = sh(returnStdout:true,script:'''#!/bin/bash -xe
VERSION=$(egrep "<version>" ''' + CHE_path + '''/pom.xml|head -2|tail -1| sed -r -e "s#.*<version>(.+)-SNAPSHOT</version>#\\1#")
[[ $VERSION =~ ^([0-9]+)\\.([0-9]+)\\.([0-9]+) ]] && BASE="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"; PREV="${BASH_REMATCH[3]}"; let PREV=PREV-1 || PREV=0;
PREVVERSION="${BASE}.${PREV}"; echo ${PREVVERSION}
''').trim()

		SHA_CHE = sh(returnStdout:true,script:"cd ${CHE_path}/ && git rev-parse --short=4 HEAD").trim()
		echo "<==== Get Che version ====="

		echo "===== Build che-dashboard =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildChe}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CHE_DB_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${CHE_DB_path}.git"]]])

		VER_CHE_DB = sh(returnStdout:true,script:"cat ${CHE_DB_path}/package.json | jq -r .version").trim()
		SHA_CHE_DB = sh(returnStdout:true,script:"cd ${CHE_DB_path}/ && git rev-parse --short=4 HEAD").trim()

		// set correct version of CRW Dashboard
		CRW_SHAs="${VER_CRW} :: ${BUILDINFO} \
:: ${DEV_path} @ ${SHA_DEV} (${VER_DEV}) \
:: ${PAR_path} @ ${SHA_PAR} (${VER_PAR}) \
:: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}) \
:: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		echo "CRW_SHAs (for dashboard) = ${CRW_SHAs}"

		// insert a longer version string which includes both CRW and Che, plus build and SHA info
		sh "sed -r -i -e \"s#(.+productVersion = ).+#\\1'${CRW_SHAs}';#g\" ${CHE_DB_path}/src/components/api/che-service.factory.ts"
		sh "egrep 'productVersion = ' ${CHE_DB_path}/src/components/api/che-service.factory.ts"

		// apply CRW CSS + fix doc links
		DOCS_VERSION = sh(returnStdout:true,script:"grep crw.docs.version ${CRW_path}/pom.xml | sed -r -e \"s#.*<.+>([0-9.SNAPSHOT-]+)</.+>#\\1#\"")
		def CRW_DOCS_BASEURL = ("https://access.redhat.com/documentation/en-us/red_hat_codeready_workspaces/" + DOCS_VERSION).trim()
		echo "CRW_DOCS_BASEURL = ${CRW_DOCS_BASEURL}"

		sh '''#!/bin/bash -xe
		cd ''' + CHE_DB_path + '''
		# ls -la src/assets/branding/
		rsync -aPr ../''' + CRW_path + '''/assembly/branding/* src/assets/branding/
		# ls -la src/assets/branding/
		mv -f src/assets/branding/branding{-crw,}.css

		# process product.json template
        sed -r \
          -e "s#@@crw.version@@#'''+CRW_SHAs + '''#g" \
 		  -e "s#@@crw.docs.baseurl@@#''' + CRW_DOCS_BASEURL + '''#g" \
        src/assets/branding/product.json.template > src/assets/branding/product.json
		rm -f src/assets/branding/product.json.template
		# cat src/assets/branding/product.json
	
		docker build -f apache.Dockerfile -t crw-dashboard:tmp .
		docker run --rm --entrypoint sh crw-dashboard:tmp -c 'tar -pzcf - /usr/local/apache2/htdocs/dashboard' > asset-dashboard.tar.gz
		'''

		echo "<===== Build che-dashboard ====="

		echo "===== Build che-workspace-loader =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildChe}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CHE_WL_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${CHE_WL_path}.git"]]])

		VER_CHE_WL = sh(returnStdout:true,script:"egrep \"<version>\" ${CHE_WL_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		// future way to get version: sh(returnStdout:true,script:"cat ${CHE_WL_path}/package.json | jq -r .version").trim()
		SHA_CHE_WL = sh(returnStdout:true,script:"cd ${CHE_WL_path}/ && git rev-parse --short=4 HEAD").trim()
		
		sh '''#!/bin/bash -xe
			cd ''' + CHE_WL_path + '''
			docker build -f apache.Dockerfile -t crw-workspace-loader:tmp .
			docker run --rm --entrypoint sh crw-workspace-loader:tmp -c 'tar -pzcf - /usr/local/apache2/htdocs/workspace-loader' > asset-workspace-loader.tar.gz
		'''

		echo "<===== Build che-workspace-loader ====="

		echo "===== Build che server assembly =====>"
		sh "mvn clean install ${MVN_FLAGS} -P native -f ${CHE_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		echo "<==== Build che server assembly ====="

		echo "===== Build CRW server assembly =====>"
		CRW_SHAs="${VER_CRW} :: ${BUILDINFO} \
:: ${DEV_path} @ ${SHA_DEV} (${VER_DEV}) \
:: ${PAR_path} @ ${SHA_PAR} (${VER_PAR}) \
:: ${CHE_DB_path} @ ${SHA_CHE_DB} (${VER_CHE_DB}) \
:: ${CHE_WL_path} @ ${SHA_CHE_WL} (${VER_CHE_WL}) \
:: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}) \
:: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		echo "CRW_SHAs (overall) = ${CRW_SHAs}"

		// TODO does crw.dashboard.version still work here? Or should we do this higher up? 
		// NOTE: VER_CHE could be 7.17.2-SNAPSHOT if we're using a .x branch instead of a tag. So this overrides what's in the crw root pom.xml

		// unpack asset-*.tgz into folder where mvn can access it
		// use that content when building assembly main and ws assembly?

		def SYNC_FILES_UP2DWN = "entrypoint.sh" // in che/dockerfiles/che/ folder

		sh '''#!/bin/bash -xe
		cd ''' + CRW_path + '''

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
		kinit "crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com@REDHAT.COM" -kt ''' + CRW_KEYTAB + '''
		klist # verify working

		# REQUIRE: skopeo
		curl -L -s -S https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/''' + MIDSTM_BRANCH + '''/product/updateBaseImages.sh -o /tmp/updateBaseImages.sh
		chmod +x /tmp/updateBaseImages.sh

  		git checkout --track origin/''' + MIDSTM_BRANCH + ''' || true
  		export GITHUB_TOKEN=''' + GITHUB_TOKEN + ''' # echo "''' + GITHUB_TOKEN + '''"
		git config user.email "nickboldt+devstudio-release@gmail.com"
		git config user.name "Red Hat Devstudio Release Bot"
		git config --global push.default matching

		# SOLVED :: Fatal: Could not read Username for "https://github.com", No such device or address :: https://github.com/github/hub/issues/1644
		git remote -v
		git config --global hub.protocol https
		git remote set-url origin https://\$GITHUB_TOKEN:x-oauth-basic@github.com/redhat-developer/''' + CRW_path + '''.git
		git remote -v

		# CRW-1213 update the che.version in the pom, so we have the latest from the upstream branch
		sed -i pom.xml -r -e "s#<che.version>.+</che.version>#<che.version>''' + VER_CHE_PREV + '''</che.version>#g"

		# Check if che-machine-exec and che-theia plugins are current in upstream repo and if not, add them
		pushd dependencies/che-plugin-registry >/dev/null
			./build/scripts/add_che_plugins.sh -b ''' + MIDSTM_BRANCH + ''' ''' + VER_CHE_PREV + '''
		popd >/dev/null

		# fetch sources to be updated
		DWNSTM_REPO="''' + DWNSTM_REPO + '''"
		pushd ${WORKSPACE} >/dev/null
		if [[ ! -d ${WORKSPACE}/targetdwn ]]; then git clone ssh://crw-build@pkgs.devel.redhat.com/${DWNSTM_REPO} targetdwn; fi
		popd >/dev/null
		pushd ${WORKSPACE}/targetdwn >/dev/null
		git checkout --track origin/''' + DWNSTM_BRANCH + ''' || true
		git config user.email crw-build@REDHAT.COM
		git config user.name "CRW Build"
		git config --global push.default matching
		popd >/dev/null

		# rsync files in upstream github to dist-git
		for d in ''' + SYNC_FILES_UP2DWN + '''; do
		if [[ -f ${WORKSPACE}/''' + CHE_path + '''/dockerfiles/che/${d} ]]; then
			rsync -zrlt ${WORKSPACE}/''' + CHE_path + '''/dockerfiles/che/${d} ${WORKSPACE}/targetdwn/${d}
		fi
		done
		# rsync files in upstream github to midstream GH
		for d in ''' + SYNC_FILES_UP2DWN + '''; do
		if [[ -f ${WORKSPACE}/''' + CHE_path + '''/dockerfiles/che/${d} ]]; then
			rsync -zrlt ${WORKSPACE}/''' + CHE_path + '''/dockerfiles/che/${d} ${WORKSPACE}/''' + CRW_path + '''/${d}
		fi
		done

		# copy rhel.Dockerfile from upstream to CRW repo
		cp ${WORKSPACE}/''' + CHE_path + '''/dockerfiles/che/rhel.Dockerfile ${WORKSPACE}/''' + CRW_path + '''/Dockerfile
		# transform Che version to CRW version (in both locations)
		sed -r -i ${WORKSPACE}/''' + CRW_path + '''/Dockerfile \
		`# transform che rhel.Dockerfile to CRW Dockerfile` \
		-e 's@ADD eclipse-che .+@\\
# NOTE: if built in Brew, use get-sources-jenkins.sh to pull latest\\
COPY assembly/codeready-workspaces-assembly-main/target/codeready-workspaces-assembly-main.tar.gz /tmp/codeready-workspaces-assembly-main.tar.gz\\
RUN tar xzf /tmp/codeready-workspaces-assembly-main.tar.gz --transform="s#.*codeready-workspaces-assembly-main/*##" -C /home/user/codeready \\&\\& rm -f /tmp/codeready-workspaces-assembly-main.tar.gz\\
@g' \
		-e 's@chmod g\\+w /home/user/cacerts@chmod 777 /home/user/cacerts@g'
		# CRW-1189 applying the fix in midstream entrypoint.sh
		sed -i ${WORKSPACE}/''' + CRW_path + '''/entrypoint.sh \
		-e '/chmod 644 \\$JAVA_TRUST_STORE || true/d' \
		-e 's/chmod 444 \\$JAVA_TRUST_STORE/chmod 444 \\$JAVA_TRUST_STORE || true/g'
		CRW_VERSION="''' + CRW_VERSION_F + '''"
		# apply patches to downstream version
		cp ${WORKSPACE}/''' + CRW_path + '''/Dockerfile ${WORKSPACE}/targetdwn/Dockerfile
		sed -i ${WORKSPACE}/targetdwn/Dockerfile \
		-e "s#FROM registry.redhat.io/#FROM #g" \
		-e "s#FROM registry.access.redhat.com/#FROM #g" \
		-e "s#COPY assembly/codeready-workspaces-assembly-main/target/#COPY #g" \
		-e "s/# *RUN yum /RUN yum /g"

		# CRW-1189 applying fix to downstream entrypoint.sh
		sed -i ${WORKSPACE}/targetdwn/entrypoint.sh \
		-e '/chmod 644 \\$JAVA_TRUST_STORE || true/d' \
		-e 's/chmod 444 \\$JAVA_TRUST_STORE/chmod 444 \\$JAVA_TRUST_STORE || true/g'

METADATA='ENV SUMMARY="Red Hat CodeReady Workspaces server container" \\\r
    DESCRIPTION="Red Hat CodeReady Workspaces server container" \\\r
    PRODNAME="codeready-workspaces" \\\r
    COMPNAME="server-rhel8" \r
LABEL summary="$SUMMARY" \\\r
      description="$DESCRIPTION" \\\r
      io.k8s.description="$DESCRIPTION" \\\r
      io.k8s.display-name=\"$DESCRIPTION" \\\r
      io.openshift.tags="$PRODNAME,$COMPNAME" \\\r
      com.redhat.component="$PRODNAME-$COMPNAME-container" \\\r
      name="$PRODNAME/$COMPNAME" \\\r
      version="'$CRW_VERSION'" \\\r
      license="EPLv2" \\\r
      maintainer="Nick Boldt <nboldt@redhat.com>" \\\r
      io.openshift.expose-services="" \\\r
      usage="" \r'
echo -e "$METADATA" >> ${WORKSPACE}/targetdwn/Dockerfile

# push changes in github to dist-git
cd ${WORKSPACE}/targetdwn
if [[ \$(git diff --name-only) ]]; then # file changed
  OLD_SHA_DWN=\$(git rev-parse HEAD) # echo ${OLD_SHA_DWN:0:8}
  git add Dockerfile ''' + SYNC_FILES_UP2DWN + ''' . -A -f
  /tmp/updateBaseImages.sh -b ''' + DWNSTM_BRANCH + ''' --nocommit || true
  # note this might fail if we sync from a tag vs. a branch
  git commit -s -m "[sync] Update from ''' + CHE_path + ''' @ ''' + SHA_CHE + ''' + ''' + CRW_path + ''' @ ''' + SHA_CRW + '''" \
    Dockerfile ''' + SYNC_FILES_UP2DWN + ''' . || true
  git push origin ''' + DWNSTM_BRANCH + ''' || true
  NEW_SHA_DWN=\$(git rev-parse HEAD) # echo ${NEW_SHA_DWN:0:8}
  if [[ "${OLD_SHA_DWN}" != "${NEW_SHA_DWN}" ]]; then hasChanged=1; fi
  echo "[sync] Updated pkgs.devel @ ${NEW_SHA_DWN:0:8} from ''' + CHE_path + ''' @ ''' + SHA_CHE + ''' + ''' + CRW_path + ''' @ ''' + SHA_CRW + '''"
else
    # file not changed, but check if base image needs an update
    # (this avoids having 2 commits for every change)
    OLD_SHA_DWN=\$(git rev-parse HEAD) # echo ${OLD_SHA_DWN:0:8}
    /tmp/updateBaseImages.sh -b ''' + DWNSTM_BRANCH + ''' || true
    NEW_SHA_DWN=\$(git rev-parse HEAD) # echo ${NEW_SHA_DWN:0:8}
    if [[ "${OLD_SHA_DWN}" != "${NEW_SHA_DWN}" ]]; then hasChanged=1; fi
fi

# push changes to github
cd ${WORKSPACE}/''' + CRW_path + '''
if [[ \$(git diff --name-only) ]]; then # file changed
    OLD_SHA_MID=\$(git rev-parse HEAD) # echo ${OLD_SHA_MID:0:8}
    git add Dockerfile ''' + SYNC_FILES_UP2DWN + ''' . -A -f
    /tmp/updateBaseImages.sh -b ''' + MIDSTM_BRANCH + ''' --nocommit || true
    # note this might fail if we sync from a tag vs. a branch
    git commit -s -m "[sync] Update from ''' + CHE_path + ''' @ ''' + SHA_CHE + '''" \
	  Dockerfile ''' + SYNC_FILES_UP2DWN + ''' . || true
    git push origin ''' + MIDSTM_BRANCH + ''' || true
    NEW_SHA_MID=\$(git rev-parse HEAD) # echo ${NEW_SHA_MID:0:8}
    if [[ "${OLD_SHA_MID}" != "${NEW_SHA_MID}" ]]; then hasChanged=1; fi
    echo "[sync] Updated GH @ ${NEW_SHA_MID:0:8} from ''' + CHE_path + ''' @ ''' + SHA_CHE + '''"
else
    # file not changed, but check if base image needs an update
    # (this avoids having 2 commits for every change)
    OLD_SHA_MID=\$(git rev-parse HEAD) # echo ${OLD_SHA_MID:0:8}
    /tmp/updateBaseImages.sh -b ''' + MIDSTM_BRANCH + ''' || true
    NEW_SHA_MID=\$(git rev-parse HEAD) # echo ${NEW_SHA_MID:0:8}
    if [[ "${OLD_SHA_MID}" != "${NEW_SHA_MID}" ]]; then hasChanged=1; fi
fi
cd ..

if [[ ''' + FORCE_BUILD + ''' == "true" ]]; then hasChanged=1; fi
if [[ ${hasChanged} -eq 1 ]]; then
	touch ${WORKSPACE}/trigger-downstream-true
fi
if [[ ${hasChanged} -eq 0 ]]; then
  echo "No changes upstream, nothing to commit"
fi
		'''

		sh "mvn clean install ${MVN_FLAGS} -f ${CRW_path}/pom.xml -Dparent.version=\"${VER_CHE}\" -Dche.version=\"${VER_CHE}\" -Dcrw.dashboard.version=\"${CRW_SHAs}\" ${MVN_EXTRA_FLAGS}"

		// Add dashboard and workspace-loader to server assembly
		sh '''#!/bin/bash -xe
			# unpack incomplete assembly
			mkdir -p /tmp/''' + CRW_path + '''-assembly-main/tomcat/webapps/dashboard/ /tmp/''' + CRW_path + '''-assembly-main/tomcat/webapps/workspace-loader/
			tar xvzf ''' + CRW_path + '''/assembly/''' + CRW_path + '''-assembly-main/target/codeready-workspaces-assembly-main.tar.gz -C /tmp/''' + CRW_path + '''-assembly-main/

			# rename incomplete assembly
			mv ''' + CRW_path + '''/assembly/''' + CRW_path + '''-assembly-main/target/codeready-workspaces-assembly-main{,-no-dashboard-no-workspace-loader}.tar.gz 

			# unpack + move dashboard artifacts
			tar xvzf ''' + CHE_DB_path + '''/asset-dashboard.tar.gz -C /tmp/''' + CRW_path + '''-assembly-main/tomcat/webapps/dashboard/
			mv /tmp/''' + CRW_path + '''-assembly-main/tomcat/webapps/dashboard/usr/local/apache2/htdocs/dashboard/* \
			   /tmp/''' + CRW_path + '''-assembly-main/codeready-workspaces-assembly-main/tomcat/webapps/dashboard/

			# unpack + move workspace-loader artifacts
			tar xvzf ''' + CHE_WL_path + '''/asset-workspace-loader.tar.gz -C /tmp/''' + CRW_path + '''-assembly-main/tomcat/webapps/workspace-loader/
			mv /tmp/''' + CRW_path + '''-assembly-main/tomcat/webapps/workspace-loader/usr/local/apache2/htdocs/workspace-loader/* \
			   /tmp/''' + CRW_path + '''-assembly-main/codeready-workspaces-assembly-main/tomcat/webapps/workspace-loader/

			# clean up temp folder
			rm -fr /tmp/''' + CRW_path + '''-assembly-main/tomcat/

			# build new complete tarball assemlby with che server, dashboard, and workspace-loader
			pushd /tmp/''' + CRW_path + '''-assembly-main/ >/dev/null; tar -pzcf codeready-workspaces-assembly-main.tar.gz ./*; popd >/dev/null
			mv /tmp/''' + CRW_path + '''-assembly-main/codeready-workspaces-assembly-main.tar.gz ''' + CRW_path + '''/assembly/''' + CRW_path + '''-assembly-main/target/

			# clean up incomplete assembly
			rm -f ''' + CRW_path + '''/assembly/''' + CRW_path + '''-assembly-main/target/codeready-workspaces-assembly-main-no-dashboard-no-workspace-loader.tar.gz
		'''

		archiveArtifacts fingerprint: true, artifacts:"**/*.log, **/assembly/*xml, **/assembly/**/*xml, ${CRW_path}/assembly/${CRW_path}-assembly-main/target/*.tar.*, **/asset-*.gz"

		echo "<===== Build CRW server assembly ====="

		def brewwebQuery = \
			"https://brewweb.engineering.redhat.com/brew/tasks?method=buildContainer&owner=crw-build/codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com&state=all&view=flat&order=-id"
		def descriptString=(
			env.ghprbPullId && env.ghprbPullId?.trim()?\
				"<a href=https://github.com/redhat-developer/${CRW_path}/pull/${env.ghprbPullId}>PR-${env.ghprbPullId}</a> ":\
				("${SCRATCH}"=="true"?\
					"<a href=${brewwebQuery}>Scratch</a> ":\
					"<a href=https://quay.io/repository/crw/server-rhel8?tab=tags>Quay</a> "\
				)\
			)\
			+ "Build #${BUILD_NUMBER} (${BUILD_TIMESTAMP}) <br/>\
 :: ${DEV_path} @ ${SHA_DEV} (${VER_DEV}) <br/>\
 :: ${PAR_path} @ ${SHA_PAR} (${VER_PAR}) <br/>\
 :: ${CHE_DB_path} @ ${SHA_CHE_DB} (${VER_CHE_DB}) <br/>\
 :: ${CHE_WL_path} @ ${SHA_CHE_WL} (${VER_CHE_WL}) <br/>\
 :: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}) <br/>\
 :: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		echo "${descriptString}"
		currentBuild.description="${descriptString}"
		}
	  }
	}
}

timeout(120) {
	node("rhel7-releng"){ stage "Run get-sources-rhpkg-container-build"
		def QUAY_REPO_PATHs=(env.ghprbPullId && env.ghprbPullId?.trim()?"":("${SCRATCH}"=="true"?"":"server-rhel8"))
		if (fileExists(WORKSPACE + '/trigger-downstream-true') || PUSH_TO_QUAY.equals("true")) {
			echo "[INFO] Trigger get-sources-rhpkg-container-build " + (env.ghprbPullId && env.ghprbPullId?.trim()?"for PR-${ghprbPullId} ":"") + \
			"with SCRATCH = ${SCRATCH}, QUAY_REPO_PATHs = ${QUAY_REPO_PATHs}, JOB_BRANCH = ${MIDSTM_BRANCH}"

			// trigger OSBS build
			build(
			job: 'get-sources-rhpkg-container-build',
			wait: false,
			propagate: false,
			parameters: [
				[
				$class: 'StringParameterValue',
				name: 'GIT_PATHs',
				value: "containers/codeready-workspaces",
				],
				[
				$class: 'StringParameterValue',
				name: 'GIT_BRANCH',
				value: "${DWNSTM_BRANCH}",
				],
				[
				$class: 'StringParameterValue',
				name: 'QUAY_REPO_PATHs',
				value: "${QUAY_REPO_PATHs}",
				],
				[
				$class: 'StringParameterValue',
				name: 'SCRATCH',
				value: "${SCRATCH}",
				],
				[
				$class: 'StringParameterValue',
				name: 'JOB_BRANCH',
				value: "${CRW_VERSION_F}",
				]
			]
			)
		} else {
			echo "No changes upstream, Brew build not triggered"
			currentBuild.result='UNSTABLE'
		}
	}
}
