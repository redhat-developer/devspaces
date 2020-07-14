#!/usr/bin/env groovy

// PARAMETERS for this pipeline:
// SOURCE_BRANCH = "master"
// getLatestImageTagsFlags="--crw23" # placeholder for flag to pass to getLatestImageTags.sh

def errorOccurred = false
timeout(120) {
    node("rhel7-releng"){ 
        try { 
            stage "Check registries"
            cleanWs()
            
            withCredentials([string(credentialsId:'devstudio-release.token', variable: 'GITHUB_TOKEN'), 
                file(credentialsId: 'crw-build.keytab', variable: 'CRW_KEYTAB')]) {
                checkout([$class: 'GitSCM', 
                        branches: [[name: "${SOURCE_BRANCH}"]], 
                        doGenerateSubmoduleConfigurations: false, 
                        poll: true,
                        extensions: [
                            [$class: 'RelativeTargetDirectory', relativeTargetDir: "crw"],
                            [$class: 'PathRestriction', excludedRegions: '', includedRegions: 'dependencies/update-digests.Jenkinsfile'],
                            [$class: 'DisableRemotePoll']
                        ],
                        submoduleCfg: [], 
                        userRemoteConfigs: [[url: "https://github.com/redhat-developer/codeready-workspaces.git"]]])
                        
                def NEW_IMAGES = sh (
                    script: 'cd ${WORKSPACE}/crw/product && ./getLatestImageTags.sh ${getLatestImageTagsFlags} --quay | sort | uniq | grep quay | \
                        tee ${WORKSPACE}/crw/dependencies/LATEST_IMAGES.new',
                    returnStdout: true
                ).trim().split()

                // check for Quay outage
                if (NEW_IMAGES.toString().indexOf("No tags matching")>-1)
                {
                    errorOccurred = true
                    error('Missing tags when reading from quay.io: may be experiencing an outage. Abort!')
                    currentBuild.result = 'ABORTED'
                }
                echo "------"
                def CURRENT_IMAGES = sh (
                    script: 'cat ${WORKSPACE}/crw/dependencies/LATEST_IMAGES',
                    returnStdout: true
                ).trim().split()
        
                sh '''#!/bin/bash -xe
                    cp ${WORKSPACE}/crw/dependencies/LATEST_IMAGES{,.prev}
                    echo "============ LATEST_IMAGES.prev ============>"
                    cat ${WORKSPACE}/crw/dependencies/LATEST_IMAGES.prev
                    echo "<============ LATEST_IMAGES ============"
                '''

                // compare new and curent images
                def newSet = NEW_IMAGES as Set
                // def currentSet = CURRENT_IMAGES as Set
                def devfileRegistryImage = newSet.find { it.contains("devfileregistry") }
                def pluginRegistryImage = newSet.find { it.contains("pluginregistry") } 
                def operatorMetadataImage = newSet.find { it.contains("operator-metadata") } 
                // echo "${pluginRegistryImage}"
                // echo "${devfileRegistryImage}"
                // newSet.each { echo "New: $it" }
                // currentSet.each { echo "Current: $it" }
                sh '''#!/bin/bash -xe
                    echo "============ LATEST_IMAGES.new 1 ============>"
                    cat ${WORKSPACE}/crw/dependencies/LATEST_IMAGES.new
                    echo "<============ LATEST_IMAGES.new 1 ============"
                '''
                def DIFF_LATEST_IMAGES_WITH_REGISTRY = sh (
                    // don't report a diff when new operator metadata or registries, or we'll never get out of this recursion loop
                    script: 'diff -u0 ${WORKSPACE}/crw/dependencies/LATEST_IMAGES.{prev,new} -I operator-metadata | grep -v "@@" | grep -v "dependencies/LATEST_IMAGES" || true',
                    returnStdout: true
                ).trim()
                def DIFF_LATEST_IMAGES_NO_REGISTRY = sh (
                    // do report a diff when new registries, so we can trigger new operator-metadata
                    script: 'diff -u0 ${WORKSPACE}/crw/dependencies/LATEST_IMAGES.{prev,new} -I operator-metadata | grep -v "@@" | grep -v "dependencies/LATEST_IMAGES" | grep -v registry  || true',
                    returnStdout: true
                ).trim()
                def DIFF_LATEST_IMAGES_METADATA = sh (
                    // check diff including operator metadata and registries, in case we forgot to update metadata
                    script: 'diff -u0 ${WORKSPACE}/crw/dependencies/LATEST_IMAGES.{prev,new} | grep -v "@@" | grep -v "dependencies/LATEST_IMAGES" | grep operator-metadata  || true',
                    returnStdout: true
                ).trim()

                // define what to do when we are ready to push changes
                def COMMITCHANGES = '''#!/bin/bash -xe
                    cd ${WORKSPACE}/crw/product && ./getLatestImageTags.sh ${getLatestImageTagsFlags} --quay | sort | uniq | grep quay > ${WORKSPACE}/crw/dependencies/LATEST_IMAGES.new

                    echo "============ LATEST_IMAGES.new 3 ============>"
                    cat ${WORKSPACE}/crw/dependencies/LATEST_IMAGES.new
                    echo "<============ LATEST_IMAGES.new 3 ============"

                    # bootstrapping: if keytab is lost, upload to 
                    # https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/credentials/store/system/domain/_/
                    # then set Use secret text above and set Bindings > Variable (path to the file) as ''' + CRW_KEYTAB + '''
                    chmod 700 ''' + CRW_KEYTAB + ''' && chown ''' + USER + ''' ''' + CRW_KEYTAB + '''
                    echo "pkgs.devel.redhat.com,10.19.208.80 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAplqWKs26qsoaTxvWn3DFcdbiBxqRLhFngGiMYhbudnAj4li9/VwAJqLm1M6YfjOoJrj9dlmuXhNzkSzvyoQODaRgsjCG5FaRjuN8CSM/y+glgCYsWX1HFZSnAasLDuW0ifNLPR2RBkmWx61QKq+TxFDjASBbBywtupJcCsA5ktkjLILS+1eWndPJeSUJiOtzhoN8KIigkYveHSetnxauxv1abqwQTk5PmxRgRt20kZEFSRqZOJUlcl85sZYzNC/G7mneptJtHlcNrPgImuOdus5CW+7W49Z/1xqqWI/iRjwipgEMGusPMlSzdxDX4JzIx6R53pDpAwSAQVGDz4F9eQ==
" >> ~/.ssh/known_hosts
                    ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

                    cd ${WORKSPACE}/crw/
                    git checkout --track origin/''' + SOURCE_BRANCH + ''' || true
                    git config user.email "nickboldt+devstudio-release@gmail.com"
                    git config user.name "Red Hat Devstudio Release Bot"
                    git config --global push.default matching
                    # SOLVED :: Fatal: Could not read Username for "https://github.com", No such device or address :: https://github.com/github/hub/issues/1644
                    git remote -v
                    git config --global hub.protocol https
                    git remote set-url origin https://\$GITHUB_TOKEN:x-oauth-basic@github.com/redhat-developer/codeready-workspaces.git
                    git remote -v

                    # replace LATES_IMAGES with new sorted/uniqd values
                    cat dependencies/LATEST_IMAGES.new | sort | uniq | grep quay > dependencies/LATEST_IMAGES
                    rm -f dependencies/LATEST_IMAGES.new

                    # generate list of NVRs, builds, and commit SHAs
                    rm -f dependencies/LATEST_IMAGES_COMMITS
                    for d in $(cat dependencies/LATEST_IMAGES); do ./product/getCommitSHAForTag.sh $d >> dependencies/LATEST_IMAGES_COMMITS; done

                    # commit changes
                    git add dependencies/LATEST_IMAGES dependencies/LATEST_IMAGES_COMMITS || true
                    git commit -m "[update] Update dependencies/LATEST_IMAGES" dependencies/LATEST_IMAGES dependencies/LATEST_IMAGES_COMMITS
                    git pull origin ''' + SOURCE_BRANCH + ''' || true
                    git push origin ''' + SOURCE_BRANCH + '''
                '''

                def buildDescription="Running..."

                if (!DIFF_LATEST_IMAGES_METADATA.equals("") && DIFF_LATEST_IMAGES_WITH_REGISTRY.equals("")) { 
                    // no changes, but a newer metadata image exists
                    buildDescription="New metadata image detected: commit changes to LATEST_IMAGES"
                    currentBuild.description=buildDescription
                    echo currentBuild.description
                    echo DIFF_LATEST_IMAGES_METADATA

                    sh COMMITCHANGES
                    currentBuild.result='UNSTABLE'
                } else if (DIFF_LATEST_IMAGES_WITH_REGISTRY.equals("")) { 
                    // no changes
                    buildDescription="No new images detected, including registries: nothing to do!"
                    currentBuild.description=buildDescription
                    echo currentBuild.description
                    currentBuild.result='UNSTABLE'
                } else {
                    // changes that don't include registry
                    if (!DIFF_LATEST_IMAGES_NO_REGISTRY.equals("")) {
                        buildDescription="Detected new images (not registries): rebuild registries + operator-metadata"
                        currentBuild.description=buildDescription
                        echo currentBuild.description
                        echo DIFF_LATEST_IMAGES_WITH_REGISTRY
                        
                        parallel firstBranch: {
                            build job: 'crw-devfileregistry_sync-github-to-pkgs.devel-pipeline', parameters: [[$class: 'BooleanParameterValue', name: 'FORCE_BUILD', value: true]]
                        }, secondBranch: {
                            build job: 'crw-pluginregistry_sync-github-to-pkgs.devel-pipeline', parameters: [[$class: 'BooleanParameterValue', name: 'FORCE_BUILD', value: true]]
                        }
                        //jobs.add(devRegJob)
                        //jobs.add(pluRegJob)
                        //parallel jobs
                        while (true) {
                            def REBUILT_IMAGES = sh (
                            script: 'cd ${WORKSPACE}/crw/product && ./getLatestImageTags.sh -c "crw/devfileregistry-rhel8 crw/pluginregistry-rhel8" --quay | sort | uniq | grep quay',
                            returnStdout: true
                            ).trim().split()
                            def rebuiltImagesSet = REBUILT_IMAGES as Set
                            def rebuiltDevfileRegistryImage = rebuiltImagesSet.find { it.contains("devfileregistry") }
                            echo "${rebuiltDevfileRegistryImage}"
                            def rebuiltPluginRegistryImage = rebuiltImagesSet.find { it.contains("pluginregistry") } 
                            echo "${rebuiltPluginRegistryImage}"
                            if (rebuiltDevfileRegistryImage!=devfileRegistryImage && rebuiltPluginRegistryImage!=pluginRegistryImage) {
                                echo "Devfile and plugin registries have been rebuilt!"
                                break
                            }
                            sleep(time:60,unit:"SECONDS")
                        }
                        sh '''#!/bin/bash -xe
                            echo "============ LATEST_IMAGES.new 2 ============>"
                            cat ${WORKSPACE}/crw/dependencies/LATEST_IMAGES.new
                            echo "<============ LATEST_IMAGES.new 2 ============"
                        '''
                    } else {
                        buildDescription="Detected new registries: rebuild operator-metadata"
                        currentBuild.description=buildDescription
                        echo currentBuild.description
                        echo DIFF_LATEST_IMAGES_WITH_REGISTRY
                    }
                    build(
                    job: 'crw-operator-metadata_sync-github-to-pkgs.devel-pipeline',
                    wait: true,
                    propagate: true,
                    parameters: [[$class: 'BooleanParameterValue', name: 'FORCE_BUILD', value: true]]
                    )

                    while (true) 
                    {
                        def rebuiltOperatorMetadataImage = sh (
                        script: 'cd ${WORKSPACE}/crw/product && ./getLatestImageTags.sh -c "crw/crw-2-rhel8-operator-metadata" --quay | sort | uniq | grep quay',
                        returnStdout: true
                        ).trim()
                        echo "${rebuiltOperatorMetadataImage}"
                        if (rebuiltOperatorMetadataImage!=operatorMetadataImage) {
                            echo "Operator metadata has been rebuilt!"
                            break
                        }
                        sleep(time:60,unit:"SECONDS")
                    }

                    sh COMMITCHANGES
                }
                archiveArtifacts fingerprint: false, artifacts:"crw/dependencies/LATEST_IMAGES*"
            }
        } catch (e) {
            if (errorOccurred) {
                return
            }
            throw e
        }
    }
}