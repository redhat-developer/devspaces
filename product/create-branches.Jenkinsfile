#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// def MIDSTM_BRANCH = "crw-2.5-rhel-8" // redhat-developer/codeready-workspaces branch to use as source of the new branches
// def FUTURE_BRANCH = "crw-2.6-rhel-8" // branch to create

def buildNode = "rhel7-releng||rhel7-32gb||rhel7-16gb||rhel7-8gb" // node label
timeout(120) {
    node("${buildNode}"){ 
        stage("Create branches") {
            wrap([$class: 'TimestamperBuildWrapper']) {
                sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ MIDSTM_BRANCH + '/product/util.groovy')
                def util = load "${WORKSPACE}/util.groovy"
                cleanWs()
                sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ MIDSTM_BRANCH + '/product/tagRelease.sh && chmod +x tagRelease.sh')
                withCredentials([string(credentialsId:'devstudio-release.token', variable: 'GITHUB_TOKEN'), file(credentialsId: 'crw-build.keytab', variable: 'CRW_KEYTAB')]) {
                    util.bootstrap(CRW_KEYTAB)
                    currentBuild.description="Create ${FUTURE_BRANCH} from ${MIDSTM_BRANCH} ..."
                    sh ('''
                        ./tagRelease.sh --branchfrom ''' + MIDSTM_BRANCH + ''' -gh ''' + FUTURE_BRANCH + ''' -ghtoken ''' + GITHUB_TOKEN
                    )
                    currentBuild.description="Created ${FUTURE_BRANCH} branches"
                } //with 
            } // wrap
        } // stage
    } // node 
} // timeout
