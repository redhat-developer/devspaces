#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// node == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram||rhel7-devstudio-releng||rhel7 or rhel7-32gb||rhel7-16gb||rhel7-8gb
// nodeBig == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram or rhel7-32gb||rhel7-16gb
// branchToBuildDev = refs/tags/19
// branchToBuildParent = refs/tags/7.15.0
// branchToBuildChe = refs/tags/7.16.x
// branchToBuildCRW = master
// BUILDINFO = ${JOB_NAME}/${BUILD_NUMBER}
// MVN_EXTRA_FLAGS = extra flags, such as to disable a module -pl '!org.eclipse.che.selenium:che-selenium-test'
// SCRATCH = true (don't push to Quay) or false (do push to Quay)

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

def MVN_FLAGS="-Dmaven.repo.local=.repository/ -V -B -e"

def buildMaven(){
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
def SHA_CHE = "SHA_CHE"

def CRW_path = "codeready-workspaces"
def VER_CRW = "VER_CRW"
def SHA_CRW = "SHA_CRW"

timeout(240) {
	node("${node}"){ stage "Build ${DEV_path}, ${PAR_path}, ${CHE_DB_path}, ${CHE_WL_path}, and ${CRW_path}"
		wrap([$class: 'TimestamperBuildWrapper']) {
        	withCredentials([string(credentialsId:'devstudio-release.token', variable: 'GITHUB_TOKEN')]) {
		cleanWs()
		buildMaven()
		installNPM()
		installGo()

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
				userRemoteConfigs: [[refspec: "+refs/pull/${env.ghprbPullId}/head:refs/remotes/origin/PR-${env.ghprbPullId}", url: "https://github.com/redhat-developer/${CRW_path}.git"]]])
		} else {
			checkout([$class: 'GitSCM', 
				branches: [[name: "${branchToBuildCRW}"]], 
				doGenerateSubmoduleConfigurations: false, 
				poll: true,
				extensions: [
					[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"],
					[$class: 'PathRestriction', excludedRegions: 'dependencies/**'],
				],
				submoduleCfg: [], 
				userRemoteConfigs: [[url: "https://github.com/redhat-developer/${CRW_path}.git"]]])
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

		VER_CHE = sh(returnStdout:true,script:"egrep \"<version>\" ${CHE_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
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

		VER_CHE_DB = sh(returnStdout:true,script:"egrep \"<version>\" ${CHE_DB_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
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

		// TODO collect assets from dashboard like this?
		//docker run --rm --entrypoint sh che-dashboard:next -c 'tar -pzcf - /usr/local/apache2/htdocs/dashboard ' > asset-che-dashboard.tar.gz

		echo "===== Build che-workspace-loader =====>"
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildChe}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CHE_WL_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${CHE_WL_path}.git"]]])

		VER_CHE_WL = sh(returnStdout:true,script:"egrep \"<version>\" ${CHE_WL_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
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
		// NOTE: VER_CHE could be 7.12.2-SNAPSHOT if we're using a .x branch instead of a tag. So this overrides what's in the crw root pom.xml

		// unpack asset-*.tgz into folder where mvn can access it
		// use that content when building assembly main and ws assembly?

		sh '''#!/bin/bash -xe
		cd ''' + CRW_path + '''
  		git checkout --track origin/''' + branchToBuildCRW + ''' || true
  		export GITHUB_TOKEN=''' + GITHUB_TOKEN + ''' # echo "''' + GITHUB_TOKEN + '''"
		git config user.email "nickboldt+devstudio-release@gmail.com"
		git config user.name "Red Hat Devstudio Release Bot"
		git config --global push.default matching

		# SOLVED :: Fatal: Could not read Username for "https://github.com", No such device or address :: https://github.com/github/hub/issues/1644
		git remote -v
		git config --global hub.protocol https
		git remote set-url origin https://\$GITHUB_TOKEN:x-oauth-basic@github.com/redhat-developer/''' + CRW_path + '''.git
		git remote -v

		# Check if che-machine-exec and che-theia plugins are current in upstream repo and if not, add them
		# NOTE: we want the version of che in the pom, not the value of che computed for the dashboard (che.version override)
		pushd dependencies/che-plugin-registry >/dev/null
			./build/scripts/add_che_plugins.sh $(cat ${WORKSPACE}/''' + CRW_path + '''/pom.xml | grep -E "<che.version>" | sed -r -e "s#.+<che.version>(.+)</che.version>#\\1#")
		popd >/dev/null
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
	node("${node}"){ stage "Run get-sources-rhpkg-container-build"
		def QUAY_REPO_PATHs=(env.ghprbPullId && env.ghprbPullId?.trim()?"":("${SCRATCH}"=="true"?"":"server-rhel8"))

		def matcher = ( "${JOB_NAME}" =~ /.*_(stable-branch|master).*/ )
		def JOB_BRANCH = (matcher.matches() ? matcher[0][1] : "master")

		def matcher2 = ( "${JOB_NAME}" =~ /.*(_PR).*/ )
		def PR_SUFFIX = (matcher2.matches() ? matcher2[0][1] : "")

		echo "[INFO] Trigger get-sources-rhpkg-container-build " + (env.ghprbPullId && env.ghprbPullId?.trim()?"for PR-${ghprbPullId} ":"") + \
		"with SCRATCH = ${SCRATCH}, QUAY_REPO_PATHs = ${QUAY_REPO_PATHs}, JOB_BRANCH = ${JOB_BRANCH}${PR_SUFFIX}"

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
			  value: "crw-2.2-rhel-8",
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
			  value: "${JOB_BRANCH}${PR_SUFFIX}",
			]
		  ]
		)
	}
}
