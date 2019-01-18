#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// node == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram||rhel7-devstudio-releng||rhel7 or rhel7-32gb||rhel7-16gb||rhel7-8gb
// nodeBig == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram or rhel7-32gb||rhel7-16gb
// branchToBuild = */master or some branch like 6.16.x
// branchToBuildDev = refs/tags/19
// branchToBuildLSJ = refs/tags/0.0.2 or */master
// MVN_EXTRA_FLAGS = extra flags, such as to disable a module -pl '!org.eclipse.che.selenium:che-selenium-test'

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

timeout(120) {
	node("${node}"){ stage "Build che-dev"
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildDev}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'che-dev']], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: 'https://github.com/eclipse/che-dev.git']]])
		// dir ('che-dev') { sh 'ls -1art' }
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f che-dev/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashDev', includes: findFiles(glob: '.repository/**').join(", ")
	}
}

timeout(120) {
	node("${node}"){ stage "Build che-parent"
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'che-parent']], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: 'https://github.com/eclipse/che-parent.git']]])
		// dir ('che-parent') { sh 'ls -1art' }
		unstash 'stashDev'
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f che-parent/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashParent', includes: findFiles(glob: '.repository/**').join(", ")
	}
}

timeout(120) {
	node("${node}"){ stage "Build che-lib"
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'che-lib']], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: 'https://github.com/eclipse/che-lib.git']]])
		// dir ('che-lib') { sh 'ls -1art' }
		unstash 'stashParent'
		installNPM()
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f che-lib/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashLib', includes: findFiles(glob: '.repository/**').join(", ")
	}
}

def LSJ_path = "che-ls-jdt"
def VER_LSJ = "VER_LSJ"
def SHA_LSJ = "SHA_LSJ"
// TODO: disable until https://github.com/eclipse/che-ls-jdt/issues/98 is fixed
// timeout(120) {
// 	node("${node}"){ stage "Build ${LSJ_path}"
// 		cleanWs()
// 		checkout([$class: 'GitSCM', 
// 			branches: [[name: "${branchToBuildLSJ}"]], 
// 			doGenerateSubmoduleConfigurations: false, 
// 			poll: true,
// 			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${LSJ_path}"]], 
// 			submoduleCfg: [], 
// 			userRemoteConfigs: [[url: "https://github.com/eclipse/${LSJ_path}.git"]]])
// 		unstash 'stashLib'
// 		installNPM()
// 		installGo()
// 		buildMaven()
// 		sh "mvn clean install -V -U -e -DskipTests -f ${LSJ_path}/pom.xml ${MVN_EXTRA_FLAGS}"
// 		stash name: 'stashLSJ', includes: findFiles(glob: '.repository/**').join(", ")
//		archiveArtifacts fingerprint: false, artifacts:"**/target/*.zip, **/target/*.tar.*, **/target/*.ear"

// 		sh "perl -0777 -p -i -e 's|(\\ +<parent>.*?<\\/parent>)| ${1} =~ /<version>/?\"\":${1}|gse' ${LSJ_path}/pom.xml"
// 		VER_LSJ = sh(returnStdout:true,script:"egrep \"<version>\" ${LSJ_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
// 		SHA_LSJ = sh(returnStdout:true,script:"cd ${LSJ_path}/ && git rev-parse HEAD").trim()
// 		echo "Built ${LSJ_path} from SHA: ${SHA_LSJ} (${VER_LSJ})"
// 	}
// }

def CHE_path = "che"
def VER_CHE = ""
def SHA_CHE = ""
timeout(180) {
	node("${nodeBig}"){ stage "Build ${CHE_path}"
		cleanWs()
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CHE_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/eclipse/${CHE_path}.git"]]])
		// TODO: disable until https://github.com/eclipse/che-ls-jdt/issues/98 is fixed; then re-enable stashLSJ, and remove stashLib
		// unstash 'stashLSJ'
		unstash 'stashLib'
		installNPM()
		installGo()
		buildMaven()
		// TODO: disable until https://github.com/eclipse/che-ls-jdt/issues/98 is fixed
		// patch - switch che-ls-jdt 0.0.2 to 0.0.3-SNAPSHOT
		// sh "sed -i -e \"s#\\(.*<che.ls.jdt.version>\\)0.0.2\\(</che.ls.jdt.version>.*\\)#\\10.0.3-SNAPSHOT\\2#\" ${CHE_path}/pom.xml"

		// disable docs from assembly main and root pom as we don't need them in CRW
		sh '''#!/bin/bash -xe
			perl -0777 -p -i -e 's|(\\ +<dependency>.*?<\\/dependency>)| ${1} =~ /<artifactId>che-docs<\\/artifactId>/?\"\":${1}|gse' che/assembly/assembly-main/pom.xml
			perl -0777 -p -i -e 's|(\\ +<dependencySet>.*?<\\/dependencySet>)| ${1} =~ /<include>org.eclipse.che.docs:che-docs<\\/include>/?\"\":${1}|gse' che/assembly/assembly-main/src/assembly/assembly.xml
			perl -0777 -p -i -e 's|(\\ +<dependency>.*?<\\/dependency>)| ${1} =~ /<artifactId>che-docs<\\/artifactId>/?\"\":${1}|gse' che/pom.xml
		'''

		sh "mvn clean install ${MVN_FLAGS} -f ${CHE_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashChe', includes: findFiles(glob: '.repository/**').join(", ")
		archiveArtifacts fingerprint: false, artifacts:"**/*.log, **/${CHE_path}/pom.xml, **/${CHE_path}/assembly/assembly-main/pom.xml, **/${CHE_path}/assembly/assembly-main/src/assembly/assembly.xml"

		// remove the <parent> from the root pom
		sh "perl -0777 -p -i -e 's|(\\ +<parent>.*?<\\/parent>)| ${1} =~ /<version>/?\"\":${1}|gse' ${CHE_path}/pom.xml"
		VER_CHE = sh(returnStdout:true,script:"egrep \"<version>\" ${CHE_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CHE = sh(returnStdout:true,script:"cd ${CHE_path}/ && git rev-parse HEAD").trim()
		echo "Built ${CHE_path} from SHA: ${SHA_CHE} (${VER_CHE})"
	}
}

def CRW_path = "codeready-workspaces"
timeout(120) {
	node("${node}"){ stage "Build ${CRW_path}"
		cleanWs()
		// for private repo, use checkout(credentialsId: 'devstudio-release')
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildCRW}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${CRW_path}"]], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: "https://github.com/redhat-developer/${CRW_path}.git"]]])
		unstash 'stashChe'
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -Pnightly -f ${CRW_path}/pom.xml ${MVN_EXTRA_FLAGS}"
		archiveArtifacts fingerprint: false, artifacts:"${CRW_path}/assembly/${CRW_path}-assembly-main/target/*.tar.*"

		sh "perl -0777 -p -i -e 's|(\\ +<parent>.*?<\\/parent>)| ${1} =~ /<version>/?\"\":${1}|gse' ${CRW_path}/pom.xml"
		VER_CRW = sh(returnStdout:true,script:"egrep \"<version>\" ${CRW_path}/pom.xml|head -1|sed -e \"s#.*<version>\\(.\\+\\)</version>#\\1#\"").trim()
		SHA_CRW = sh(returnStdout:true,script:"cd ${CRW_path}/ && git rev-parse HEAD").trim()
		echo "Built ${CRW_path} from SHA: ${SHA_CRW} (${VER_CRW})"

		// sh 'printenv | sort'
		def descriptString="Build #${BUILD_NUMBER} (${BUILD_TIMESTAMP}) <br/> :: ${LSJ_path} @ ${SHA_LSJ} (${VER_LSJ}) <br/> :: ${CHE_path} @ ${SHA_CHE} (${VER_CHE}) <br/> :: ${CRW_path} @ ${SHA_CRW} (${VER_CRW})"
		echo "${descriptString}"
		currentBuild.description="${descriptString}"
	}
}

timeout(120) {
	node("${node}"){ stage "Run get-sources-rhpkg-container-build"
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
		      value: "codeready-1.0-rhel-7",
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
		    ]
		  ]
		)
	}
}