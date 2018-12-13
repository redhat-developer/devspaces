#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// node == slave label, eg., rhel7-devstudio-releng-16gb-ram||rhel7-16gb-ram or rhel7-32gb
// branchToBuild = */master or some branch like 6.16.x
// branchToBuildDev = refs/tags/19
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
	node("${node}"){ stage 'Build Che Dev'
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuildDev}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', 
				relativeTargetDir: 'che-dev']], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: 'https://github.com/eclipse/che-dev.git']]])
		// dir ('che-dev') { sh 'ls -1art' }
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f che-dev/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashDev', includes: findFiles(glob: '.repository/**').join(", ")
	}
}

timeout(120) {
	node("${node}"){ stage 'Build Che Parent'
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', 
				relativeTargetDir: 'che-parent']], 
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
	node("${node}"){ stage 'Build Che Lib'
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', 
				relativeTargetDir: 'che-lib']], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: 'https://github.com/eclipse/che-lib.git']]])
		// dir ('che-lib') { sh 'ls -1art' }
		unstash 'stashParent'
		installNPM()
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f che-lib/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashLib', include: findFiles(glob: '.repository/**').join(", ")
	}
}

timeout(120) {
	node("${node}"){ stage 'Build Che ls-jdt'
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', 
				relativeTargetDir: 'che-ls-jdt']], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: 'https://github.com/eclipse/che-ls-jdt.git']]])
		// dir ('che-ls-jdt') { sh 'ls -1art' }
		unstash 'stashLib'
		installNPM()
		installGo()
		buildMaven()
		sh "mvn clean install -V -U -e -DskipTests -f che-ls-jdt/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashLsjdt', include: findFiles(glob: '.repository/**').join(", ")
		archive includes:"**/target/*.zip, **/target/*.tar.*, **/target/*.ear"
	}
}

timeout(180) {
	node("${node}"){ stage 'Build Che'
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', 
				relativeTargetDir: 'che']], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: 'https://github.com/eclipse/che.git']]])
		// dir ('che') { sh 'ls -lart' }
		unstash 'stashLsjdt'
		installNPM()
		installGo()
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f che/pom.xml ${MVN_EXTRA_FLAGS}"
		stash name: 'stashChe', include: findFiles(glob: '.repository/**').join(", ")
		archive includes:"**/*.log"
	}
}

timeout(120) {
	node("${node}"){ stage 'Build CRW'
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			poll: true,
			extensions: [[$class: 'RelativeTargetDirectory', 
				relativeTargetDir: 'codeready-workspaces']], 
				submoduleCfg: [], 
				credentialsId: 'devstudio-release',
				userRemoteConfigs: [[url: 'git@github.com:redhat-developer/codeready-workspaces.git']]
		])
		// dir ('codeready-workspaces') { sh "ls -lart" }
		unstash 'stashChe'
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f codeready-workspaces/pom.xml ${MVN_EXTRA_FLAGS}"
		archiveArtifacts fingerprint: false, artifacts:'codeready-workspaces/assembly/codeready-workspaces-assembly-main/target/*.tar.*'

		// sh 'printenv | sort'
		BUILD_VER = sh(returnStdout:true,script:'egrep "<version>" codeready-workspaces/pom.xml|head -1|sed -e "s#.*<version>\\(.\\+\\)</version>#\\1#"').trim()
		BUILD_SHA = sh(returnStdout:true,script:'cd codeready-workspaces/ && git rev-parse HEAD').trim()
		echo "Build #${BUILD_NUMBER} :: ${BUILD_VER} :: ${BUILD_SHA} :: ${BUILD_TIMESTAMP}"
		currentBuild.description="Build #${BUILD_NUMBER} :: ${BUILD_VER} :: ${BUILD_SHA} :: ${BUILD_TIMESTAMP}"
	}
}

