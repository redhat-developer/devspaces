#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// node == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram||rhel7-devstudio-releng||rhel7 or rhel7-32gb||rhel7-16gb||rhel7-8gb
// nodeBig == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram or rhel7-32gb||rhel7-16gb
// branchToBuildDev = refs/tags/20
// branchToBuildParent = refs/tags/7.0.0-RC-2.0
// branchToBuildLib = refs/tags/7.0.0-RC-2.0
// branchToBuildChe = refs/tags/7.0.0-RC-2.0 or */*/7.0.0-RC-2.x or */master
// branchToBuildLSJ = refs/tags/0.0.3 or */master or a SHA like 095d753f42dad32c47b1e9ae46a71bf424e98e7e
// branchToBuildCRW = */7.0.0-RC-2.x or */master
// BUILDINFO = ${JOB_NAME}/${BUILD_NUMBER}
// // MVN_EXTRA_FLAGS = extra flags, such as to disable a module -pl '!org.eclipse.che.selenium:che-selenium-test'

def installNPM(){
	def nodeHome = tool 'nodejs-10.9.0'
	env.PATH="${env.PATH}:${nodeHome}/bin"
	sh "npm install -g yarn"
	sh "npm version"
}

def installGo(){
	def goHome = tool 'go-1.10'
	env.PATH="${env.PATH}:${goHome}/bin"
	sh "go version"
}

def MVN_FLAGS="-Dmaven.repo.local=.repository/ -V -B -e"

def buildMaven(){
	def mvnHome = tool 'maven-3.5.4'
	env.PATH="${env.PATH}:${mvnHome}/bin"
}

def DEV_path = "che-dev"
def VER_DEV = "VER_DEV"
def SHA_DEV = "SHA_DEV"
timeout(120) {
	node("${node}"){ stage "Build ${DEV_path}"
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildDev}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${DEV_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${DEV_path}.git"]]])
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f ${DEV_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashDev', includes: findFiles(glob: '.repository/**').join(", ")

		VER_DEV = sh(returnStdout:true,script:"egrep \"<version>\" ${DEV_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_DEV = sh(returnStdout:true,script:"cd ${DEV_path}/ && git rev-parse --short=4 HEAD").trim()
	}
}

def PAR_path = "che-parent"
def VER_PAR = "VER_PAR"
def SHA_PAR = "SHA_PAR"
timeout(120) {
	node("${node}"){ stage "Build ${PAR_path}"
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildParent}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${PAR_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${PAR_path}.git"]]])
		unstash 'stashDev'
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f ${PAR_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashParent', includes: findFiles(glob: '.repository/**').join(", ")

		VER_PAR = sh(returnStdout:true,script:"egrep \"<version>\" ${PAR_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_PAR = sh(returnStdout:true,script:"cd ${PAR_path}/ && git rev-parse --short=4 HEAD").trim()
	}
}

def LIB_path = "che-lib"
def VER_LIB = "VER_LIB"
def SHA_LIB = "SHA_LIB"
timeout(120) {
	node("${node}"){ stage "Build ${LIB_path}"
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildLib}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${LIB_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${LIB_path}.git"]]])
		unstash 'stashParent'
		installNPM()
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f ${LIB_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashLib', includes: findFiles(glob: '.repository/**').join(", ")

		sh "perl -0777 -p -i -e 's|(\\ +<parent>.*?<\\/parent>)| ${1} =~ /<version>/?\"\":${1}|gse' ${LIB_path}/pom.xml"
		VER_LIB = sh(returnStdout:true,script:"egrep \"<version>\" ${LIB_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_LIB = sh(returnStdout:true,script:"cd ${LIB_path}/ && git rev-parse --short=4 HEAD").trim()
	}
}

def LSJ_path = "che-ls-jdt"
def VER_LSJ = "VER_LSJ"
def SHA_LSJ = "SHA_LSJ"
timeout(120) {
	node("${node}"){ stage "Build ${LSJ_path}"
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildLSJ}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${LSJ_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${LSJ_path}.git"]]])
		unstash 'stashLib'
		installNPM()
		installGo()
		buildMaven()
		sh "mvn clean install -V -U -e -DskipTests -f ${LSJ_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashLSJ', includes: findFiles(glob: '.repository/**').join(", ")
		archiveArtifacts fingerprint: false, artifacts:"**/target/*.zip, **/target/*.tar.*, **/target/*.ear"

		sh "perl -0777 -p -i -e 's|(\\ +<parent>.*?<\\/parent>)| ${1} =~ /<version>/?\"\":${1}|gse' ${LSJ_path}/pom.xml"
		VER_LSJ = sh(returnStdout:true,script:"egrep \"<version>\" ${LSJ_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_LSJ = sh(returnStdout:true,script:"cd ${LSJ_path}/ && git rev-parse --short=4 HEAD").trim()
		echo "[INFO] Built ${LSJ_path} :: ${SHA_LSJ} (${VER_LSJ})"
	}
}

def CRW_SHAs = ""

def CRW_path = "codeready-workspaces"
def VER_CRW = "VER_CRW"
def SHA_CRW = "SHA_CRW"
timeout(120) {
	node("${node}"){ stage "Get ${CRW_path} version"
		cleanWs()
		// for private repo, use checkout(credentialsId: 'devstudio-release')
		if (env.ghprbPullId && env.ghprbPullId?.trim()) { 
			checkout([$class: 'GitSCM', 
				branches: [[name: "FETCH_HEAD"]], 
				doGenerateSubmoduleConfigurations: false, 
				poll: true,
				extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"], [$class: 'LocalBranch']], 
				submoduleCfg: [], 
				userRemoteConfigs: [[refspec: "+refs/pull/${env.ghprbPullId}/head:refs/remotes/origin/PR-${env.ghprbPullId}", url: "https://github.com/redhat-developer/${CRW_path}.git"]]])
		} else {
			checkout([$class: 'GitSCM', 
				branches: [[name: "${branchToBuildCRW}"]], 
				doGenerateSubmoduleConfigurations: false, 
				poll: true,
				extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"]], 
				submoduleCfg: [], 
				userRemoteConfigs: [[url: "https://github.com/redhat-developer/${CRW_path}.git"]]])
		}
		VER_CRW = sh(returnStdout:true,script:"egrep \"<version>\" ${CRW_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CRW = sh(returnStdout:true,script:"cd ${CRW_path}/ && git rev-parse --short=4 HEAD").trim()
	}
}

def CHE_path = "che"
def VER_CHE = "VER_CHE"
def SHA_CHE = "SHA_CHE"
timeout(180) {
	node("${nodeBig}"){ stage "Build ${CHE_path}"
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildChe}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CHE_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${CHE_path}.git"]]])
		unstash 'stashLSJ'
		installNPM()
		installGo()
		buildMaven()
		// patch - switch che-ls-jdt version to a different one
		// sh "sed -i -e \"s#\\(.*<che.ls.jdt.version>\\)0.0.3\\(</che.ls.jdt.version>.*\\)#\\10.0.4-SNAPSHOT\\2#\" ${CHE_path}/pom.xml"

		// disable docs from assembly main and root pom as we don't need them in CRW
		sh '''#!/bin/bash -xe
			perl -0777 -p -i -e 's|(\\ +<dependency>.*?<\\/dependency>)| ${1} =~ /<artifactId>che-docs<\\/artifactId>/?\"\":${1}|gse' che/assembly/assembly-main/pom.xml
			perl -0777 -p -i -e 's|(\\ +<dependencySet>.*?<\\/dependencySet>)| ${1} =~ /<include>org.eclipse.che.docs:che-docs<\\/include>/?\"\":${1}|gse' che/assembly/assembly-main/src/assembly/assembly.xml
			perl -0777 -p -i -e 's|(\\ +<dependency>.*?<\\/dependency>)| ${1} =~ /<artifactId>che-docs<\\/artifactId>/?\"\":${1}|gse' che/pom.xml
		'''

		VER_CHE = sh(returnStdout:true,script:"egrep \"<version>\" ${CHE_path}/pom.xml|head -2|tail -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CHE = sh(returnStdout:true,script:"cd ${CHE_path}/ && git rev-parse --short=4 HEAD").trim()

		// set correct version of CRW Dashboard
		CRW_SHAs="${VER_CRW} :: ${BUILDINFO} \
:: ${DEV_path} @ ${SHA_DEV} (${VER_DEV}) \
:: ${PAR_path} @ ${SHA_PAR} (${VER_PAR}) \
:: ${LIB_path} @ ${SHA_LIB} (${VER_LIB}) \
:: ${LSJ_path} @ ${SHA_LSJ} (${VER_LSJ}) \
:: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}) \
:: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		// echo "CRW_SHAs = ${CRW_SHAs}"

		// insert a longer version string which includes both CRW and Che, plus build and SHA info
		sh "sed -i -e \"s#\\(.\\+productVersion = \\).\\+#\\1'${CRW_SHAs}';#g\" che/dashboard/src/components/branding/che-branding.factory.ts"

		// apply CRW CSS
		sh '''#!/bin/bash -xe
			rawBranch=${branchToBuildCRW##*/}
			curl -S -L --create-dirs -o che/dashboard/src/assets/branding/branding.css \
				https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/${rawBranch}/assembly/assembly-dashboard-war/src/main/webapp/assets/branding/branding-crw.css
			cat che/dashboard/src/assets/branding/branding.css
		'''

		sh "mvn clean install ${MVN_FLAGS} -P native -f ${CHE_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashChe', includes: findFiles(glob: '.repository/**').join(", ")
		archiveArtifacts fingerprint: false, artifacts:"**/*.log, **/${CHE_path}/pom.xml, **/${CHE_path}/assembly/assembly-main/pom.xml, **/${CHE_path}/assembly/assembly-main/src/assembly/assembly.xml"

		echo "[INFO] Built ${CHE_path} :: ${CRW_SHAs}"
	}
}

timeout(120) {
	node("${node}"){ stage "Build ${CRW_path}"
		cleanWs()
		// for private repo, use checkout(credentialsId: 'devstudio-release')
		if (env.ghprbPullId && env.ghprbPullId?.trim()) { 
			checkout([$class: 'GitSCM', 
				branches: [[name: "FETCH_HEAD"]], 
				doGenerateSubmoduleConfigurations: false, 
				poll: true,
				extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"], [$class: 'LocalBranch']], 
				submoduleCfg: [], 
				userRemoteConfigs: [[refspec: "+refs/pull/${env.ghprbPullId}/head:refs/remotes/origin/PR-${env.ghprbPullId}", url: "https://github.com/redhat-developer/${CRW_path}.git"]]])
		} else {
			checkout([$class: 'GitSCM', 
				branches: [[name: "${branchToBuildCRW}"]], 
				doGenerateSubmoduleConfigurations: false, 
				poll: true,
				extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"]], 
				submoduleCfg: [], 
				userRemoteConfigs: [[url: "https://github.com/redhat-developer/${CRW_path}.git"]]])
		}
		unstash 'stashChe'
		buildMaven()

		CRW_SHAs="${VER_CRW} :: ${BUILDINFO} \
:: ${DEV_path} @ ${SHA_DEV} (${VER_DEV}) \
:: ${PAR_path} @ ${SHA_PAR} (${VER_PAR}) \
:: ${LIB_path} @ ${SHA_LIB} (${VER_LIB}) \
:: ${LSJ_path} @ ${SHA_LSJ} (${VER_LSJ}) \
:: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}) \
:: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		// echo "CRW_SHAs = ${CRW_SHAs}"

		sh "mvn clean install ${MVN_FLAGS} -f ${CRW_path}/pom.xml -Dcrw.dashboard.version=\"${CRW_SHAs}\" ${MVN_EXTRA_FLAGS}"
		archiveArtifacts fingerprint: true, artifacts:"${CRW_path}/assembly/${CRW_path}-assembly-main/target/*.tar.*"

		echo "[INFO] Built ${CRW_path} :: ${CRW_SHAs}"

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
 :: ${LIB_path} @ ${SHA_LIB} (${VER_LIB}) <br/>\
 :: ${LSJ_path} @ ${SHA_LSJ} (${VER_LSJ}) <br/>\
 :: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}) <br/>\
 :: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		echo "${descriptString}"
		currentBuild.description="${descriptString}"
	}
}

timeout(120) {
	node("${node}"){ stage "Run get-sources-rhpkg-container-build"
		def QUAY_REPO_PATHs=(env.ghprbPullId && env.ghprbPullId?.trim()?"":("${SCRATCH}"=="true"?"":"server-rhel8"))

		def matcher = ( "${JOB_NAME}" =~ /.*_(stable-branch|master).*/ )
		def JOB_BRANCH= (matcher.matches() ? matcher[0][1] : "stable-branch")

		echo "[INFO] Trigger get-sources-rhpkg-container-build " + (env.ghprbPullId && env.ghprbPullId?.trim()?"for PR-${ghprbPullId} ":"") + \
		"with SCRATCH = ${SCRATCH}, QUAY_REPO_PATHs = ${QUAY_REPO_PATHs}, JOB_BRANCH = ${JOB_BRANCH}"

		// trigger OSBS build
		build(
		  job: 'get-sources-rhpkg-container-build',
		  wait: false,
		  propagate: false,
		  parameters: [
			[
			  $class: 'StringParameterValue',
			  name: 'GIT_PATH',
			  value: "containers/codeready-workspaces",
			],
			[
			  $class: 'StringParameterValue',
			  name: 'GIT_BRANCH',
			  value: "crw-2.0-rhel-8",
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
			  value: "${JOB_BRANCH}",
			]
		  ]
		)
	}
}
