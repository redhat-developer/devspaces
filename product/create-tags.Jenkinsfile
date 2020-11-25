#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// def MIDSTM_BRANCH = "crw-2.5-rhel-8" // redhat-developer/codeready-workspaces branch to use as source of the new branches
// def FUTURE_BRANCH = "crw-2.6-rhel-8" // redhat-developer/codeready-workspaces branch to use as source of the scripts run
// def CRW_TAG = "2.5.0" // tag to create

def buildNode = "rhel7-releng||rhel7-32gb||rhel7-16gb||rhel7-8gb" // node label
timeout(120) {
    node("${buildNode}"){ 
        stage("Create tags") {
            wrap([$class: 'TimestamperBuildWrapper']) {
                sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ FUTURE_BRANCH + '/product/util.groovy')
                def util = load "${WORKSPACE}/util.groovy"
                cleanWs()
                sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ FUTURE_BRANCH + '/product/tagRelease.sh && chmod +x tagRelease.sh')
                sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ FUTURE_BRANCH + '/product/containerExtract.sh && chmod +x containerExtract.sh')
                withCredentials([string(credentialsId:'devstudio-release.token', variable: 'GITHUB_TOKEN'), file(credentialsId: 'crw-build.keytab', variable: 'CRW_KEYTAB')]) {
                    util.bootstrap(CRW_KEYTAB)

                    // to ensure correct permissions, use util.cloneRepo instead of relying on local user permissions 
                    String pduser = "crw-build"
                    String containers= '''
codeready-workspaces-configbump \
codeready-workspaces-operator \
codeready-workspaces-operator-metadata \
codeready-workspaces-devfileregistry \
codeready-workspaces-imagepuller \
\
codeready-workspaces-jwtproxy \
codeready-workspaces-machineexec \
codeready-workspaces-pluginbroker-artifacts \
codeready-workspaces-pluginbroker-metadata \
codeready-workspaces-plugin-intellij \
\
codeready-workspaces-plugin-java11-openj9 \
codeready-workspaces-plugin-java11 \
codeready-workspaces-plugin-java8-openj9 \
codeready-workspaces-plugin-java8 \
codeready-workspaces-plugin-kubernetes \
\
codeready-workspaces-plugin-openshift \
codeready-workspaces-pluginregistry \
codeready-workspaces \
codeready-workspaces-stacks-cpp \
codeready-workspaces-stacks-dotnet \
\
codeready-workspaces-stacks-golang \
codeready-workspaces-stacks-php \
codeready-workspaces-theia-dev \
codeready-workspaces-theia-endpoint \
codeready-workspaces-theia \
\
codeready-workspaces-traefik \
'''
                    for (String d : containers.split(' |\\\\')) {
                        String container = d.trim()
                        if (container?.trim()) {
                            String desc = "git clone -b ${MIDSTM_BRANCH} ssh://${pduser}@pkgs.devel.redhat.com/containers/${container} containers_${container}"
                            currentBuild.description="${desc} ..."
                            println "##  ${desc}"
                            util.cloneRepo("ssh://crw-build@pkgs.devel.redhat.com/containers/${container}", "/tmp/tmp-checkouts/containers_${container}", MIDSTM_BRANCH)
                        }
                    }

                    // to ensure correct permissions, use util.cloneRepo instead of relying on local user permissions 
                    String projects= '''
codeready-workspaces \
codeready-workspaces-chectl \
codeready-workspaces-deprecated \
codeready-workspaces-images \
codeready-workspaces-operator \
codeready-workspaces-productization \
codeready-workspaces-theia \
'''
                    for (String d : projects.split(' |\\\\')) {
                        String project = d.trim()
                        if (project?.trim()) {
                            String desc = "git clone -b ${MIDSTM_BRANCH} git@github.com:redhat-developer/${project}.git projects_${project}"
                            currentBuild.description="${desc} ..."
                            println "##  ${desc}"
                            util.cloneRepo("https://github.com/redhat-developer/${project}.git", "/tmp/tmp-checkouts/projects_${project}", MIDSTM_BRANCH)
                        }
                    }

                    currentBuild.description="Create ${CRW_TAG} tags in ${MIDSTM_BRANCH} ..."
                    // run tagRelease script to tag repos, but use previously checked out code from the above steps
                    sh ("./tagRelease.sh -t ${CRW_TAG} -gh ${MIDSTM_BRANCH} -ghtoken ${GITHUB_TOKEN} -pd ${MIDSTM_BRANCH} -pduser ${pduser}")
                    currentBuild.description="Created ${CRW_TAG} tags"
                } //with 
            } // wrap
        } // stage
    } // node 
} // timeout
