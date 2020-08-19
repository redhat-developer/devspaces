#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// def MIDSTM_BRANCH = "crw-2.4-rhel-8" // upstream source repo branch from which to find and sync commits to pkgs.devel repo
// def CSV_VERSION = "2.4.0" // version of CRW to use to update sources

def MIDSTM_REPO = "redhat-developer/codeready-workspaces"

def MVN_FLAGS="-Dmaven.repo.local=.repository/ -V -B -e"

def installMaven(){
	def mvnHome = tool 'maven-3.6.2'
	env.PATH="/qa/tools/opt/x86_64/openjdk11_last/bin:${env.PATH}:${mvnHome}/bin"
	sh "mvn -v"
}

def buildNode = "rhel7-releng" // node label
timeout(120) {
	node("${buildNode}"){ stage "Sync repos"
    wrap([$class: 'TimestamperBuildWrapper']) {
		cleanWs()
        installMaven()
        withCredentials([string(credentialsId:'devstudio-release.token', variable: 'GITHUB_TOKEN'), 
            file(credentialsId: 'crw-build.keytab', variable: 'CRW_KEYTAB')]) {
            checkout([$class: 'GitSCM',
                branches: [[name: "${MIDSTM_BRANCH}"]],
                doGenerateSubmoduleConfigurations: false,
                credentialsId: 'devstudio-release',
                poll: false,
                extensions: [
                [$class: 'RelativeTargetDirectory', relativeTargetDir: "targetmid"],
                [$class: 'DisableRemotePoll']
                ],
                submoduleCfg: [],
                userRemoteConfigs: [[url: "https://github.com/${MIDSTM_REPO}.git"]]])

            sh '''

cd targetmid/
./product/updateVersionAndRegistryTags.sh -b ''' + MIDSTM_BRANCH + ''' -v ''' + CSV_VERSION + ''' -w $(pwd)

'''
            }
        }
	}
}

// TODO enable jobs and trigger them!

