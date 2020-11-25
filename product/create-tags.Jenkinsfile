#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// def MIDSTM_BRANCH = "crw-2.5-rhel-8" // redhat-developer/codeready-workspaces branch to use as source of the new branches
// def CRW_TAG = "2.5.0" // tag to create

def buildNode = "rhel7-releng||rhel7-32gb||rhel7-16gb||rhel7-8gb" // node label
timeout(120) {
    node("${buildNode}"){ 
        stage("Create tags") {
            wrap([$class: 'TimestamperBuildWrapper']) {
                sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ MIDSTM_BRANCH + '/product/util.groovy')
                def util = load "${WORKSPACE}/util.groovy"
                cleanWs()
                sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ MIDSTM_BRANCH + '/product/tagRelease.sh && chmod +x tagRelease.sh')
                sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ MIDSTM_BRANCH + '/product/containerExtract.sh && chmod +x containerExtract.sh')
                withCredentials([string(credentialsId:'devstudio-release.token', variable: 'GITHUB_TOKEN'), file(credentialsId: 'crw-build.keytab', variable: 'CRW_KEYTAB')]) {
                    util.bootstrap(CRW_KEYTAB)

                    // TODO check if this works / is this needed?
                    // println "##  Clone github.com/redhat-developer/codeready-workspaces-operator.git"
                    // util.cloneRepo("https://github.com/redhat-developer/codeready-workspaces-operator.git", "/tmp/tmp-checkouts/sources/projects_codeready-workspaces-operator", MIDSTM_BRANCH)

                    currentBuild.description="Create ${CRW_TAG} tags in ${MIDSTM_BRANCH} ..."
                    sh ('''
                    ./tagRelease.sh -t ''' + CRW_TAG + ''' -gh ''' + MIDSTM_BRANCH + ''' -ghtoken ''' + GITHUB_TOKEN + ''' -pd ''' + MIDSTM_BRANCH + ''' -pduser crw-build 
                    ''')
                    currentBuild.description="Created ${CRW_TAG} tags"
                } //with 
            } // wrap
        } // stage
    } // node 
} // timeout
