#!/usr/bin/env groovy

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

def MVN_FLAGS="-Pfast -Dmaven.repo.local=.repository/ -V -ff -B -e -Dskip-enforce -DskipTests -Dskip-validate-sources -Dfindbugs.skip -DskipIntegrationTests=true -Dmdep.analyze.skip=true -Dmaven.javadoc.skip -Dgpg.skip -Dorg.slf4j.simpleLogger.showDateTime=true -Dorg.slf4j.simpleLogger.dateTimeFormat=HH:mm:ss -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn"

def buildMaven(){
	def mvnHome = tool 'maven-3.5.4'
	env.PATH="${env.PATH}:${mvnHome}/bin"
}

// parallel {
// 	node("${node}"){ stage 'Build Che Dev'
// 		checkout([$class: 'GitSCM', 
// 			branches: [[name: "${branchToBuildDev}"]], 
// 			doGenerateSubmoduleConfigurations: false, 
// 			extensions: [[$class: 'RelativeTargetDirectory', 
// 				relativeTargetDir: 'che-dev']], 
// 			submoduleCfg: [], 
// 			userRemoteConfigs: [[url: 'https://github.com/eclipse/che-dev.git']]])
// 		dir ('che-dev') { sh 'ls -1art' }
// 		buildMaven()
// 		sh "mvn clean install ${MVN_FLAGS} -f che-dev/pom.xml"
// 		def filesDev = findFiles(glob: '.repository/**')
// 		stash name: 'stashDev', includes: filesParent.join(", ")
// 	}
	node("${node}"){ stage 'Build Che Parent'
		checkout([$class: 'GitSCM', 
			branches: [[name: "${branchToBuild}"]], 
			doGenerateSubmoduleConfigurations: false, 
			extensions: [[$class: 'RelativeTargetDirectory', 
				relativeTargetDir: 'che-parent']], 
			submoduleCfg: [], 
			userRemoteConfigs: [[url: 'https://github.com/eclipse/che-parent.git']]])
		// dir ('che-parent') { sh 'ls -1art' }
		buildMaven()
		sh "mvn clean install ${MVN_FLAGS} -f che-parent/pom.xml"
		def filesParent = findFiles(glob: '.repository/**')
		stash name: 'stashParent', includes: filesParent.join(", ")
	}
// }

node("${node}"){ stage 'Build Che Lib'
	checkout([$class: 'GitSCM', 
		branches: [[name: "${branchToBuild}"]], 
		doGenerateSubmoduleConfigurations: false, 
		extensions: [[$class: 'RelativeTargetDirectory', 
			relativeTargetDir: 'che-lib']], 
		submoduleCfg: [], 
		userRemoteConfigs: [[url: 'https://github.com/eclipse/che-lib.git']]])
	// dir ('che-lib') { sh 'ls -1art' }
	unstash 'stashParent'
	installNPM()
	buildMaven()
	sh "mvn clean install ${MVN_FLAGS} -f che-lib/pom.xml"
	def filesLib = findFiles(glob: '.repository/**')
	stash name: 'stashLib', include: filesLib.join(", ")
}

node("${node}"){ stage 'Build Che'
	checkout([$class: 'GitSCM', 
		branches: [[name: "${branchToBuild}"]], 
		doGenerateSubmoduleConfigurations: false, 
		extensions: [[$class: 'RelativeTargetDirectory', 
			relativeTargetDir: 'che']], 
		submoduleCfg: [], 
		userRemoteConfigs: [[url: 'https://github.com/eclipse/che.git']]])
	// dir ('che') { sh 'ls -lart' }
	unstash 'stashLib'
	installNPM()
	installGo()
	buildMaven()
	sh "mvn clean install ${MVN_FLAGS} -f che/pom.xml"
	def filesChe = findFiles(glob: '.repository/**')
	stash name: 'stashChe', include: filesChe.join(", ")
	archive includes:"**/*.log"
}

node("${node}"){ stage 'Build CRW'
	checkout([$class: 'GitSCM', 
		branches: [[name: "${branchToBuild}"]], 
		doGenerateSubmoduleConfigurations: false, 
		extensions: [[$class: 'RelativeTargetDirectory', 
			relativeTargetDir: 'codeready-workspaces']], 
		submoduleCfg: [], 
		credentialsId: 'devstudio-release',
		userRemoteConfigs: [[url: 'https://github.com/redhat-developer/codeready-workspaces.git']]])
	// dir ('codeready-workspaces') { sh "ls -lart" }
	unstash 'stashChe'
	buildMaven()
	sh "mvn clean install ${MVN_FLAGS} -f codeready-workspaces/pom.xml"
	archive includes:"codeready-workspaces/assembly/codeready-workspaces-assembly-main/target/*.tar.*"
}
