#!/usr/bin/env groovy

import groovy.transform.Field

// PARAMETERS for this pipeline:
//   CONTAINERS - list of containers to push, without the crw/ or codeready-workspaces- prefix and without -rhel8 suffix
//   TAGS       - tags to push in addition to the latest one (2.5-4) and the base one (2.5), eg., also update latest tag

String MIDSTM_BRANCH = "crw-2.5-rhel-8" // target branch, eg., crw-2.5-rhel-8

def checkFailure(arrayLines,serverName,errorOccurred)
{
    arrayLines.each  { 
        line -> if (line?.toString().indexOf("No tags matching")>-1 || line?.toString().indexOf("ERROR")>-1) { 
            errorOccurred = errorOccurred + line + '\n'; 
            currentBuild.result = 'FAILURE'
        }
    }
    return errorOccurred
}

def errorOccurred = ""
def buildNode = "rhel7-32gb||rhel7-16gb||rhel7-8gb||rhel7-releng" // node label
@Field String DIFF_LATEST_IMAGES_QUAY_V_STORED = "trigger-update"
timeout(30) {
    node("${buildNode}"){ 
        try { 
            stage("Copy from OSBS to Quay") {
                wrap([$class: 'TimestamperBuildWrapper']) {
                    sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ MIDSTM_BRANCH + '/product/util.groovy')
                    def util = load "${WORKSPACE}/util.groovy"
                    cleanWs()
                    CRW_VERSION = util.getCrwVersion(MIDSTM_BRANCH)
                    println "CRW_VERSION = '" + CRW_VERSION + "'"
                    util.installSkopeo(CRW_VERSION)
                    util.installYq()

                    withCredentials([string(credentialsId:'quay.io-crw-token', variable: 'QUAY_TOKEN'),
                        file(credentialsId: 'crw-build.keytab', variable: 'CRW_KEYTAB')]) {
                        util.bootstrap(CRW_KEYTAB)

                        sh (
                            script: 'curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+MIDSTM_BRANCH+'/product/getLatestImageTags.sh && chmod +x getLatestImageTags.sh',
                            returnStdout: true).trim().split( '\n' )

                        currentBuild.description="Copying: " + CONTAINERS.trim().replaceAll(" ",", ")

                        def NEW_NVR = ""
                        parallel copy_to_quay: {
                            sh('''#!/bin/bash -xe
QUAY_REGISTRY="quay.io/crw/"
QUAY_USER="crw+crwci"

echo "[INFO]: Log into quay.io..."
echo "${QUAY_TOKEN}" | docker login -u="${QUAY_USER}" --password-stdin ${QUAY_REGISTRY}

echo " ########################################### "
echo " Copy latest images in osbs to quay: ''' + CONTAINERS.trim() + '''"
echo " ########################################### "
for c in ''' + CONTAINERS.trim() + '''; do
    d=codeready-workspaces-${c}-rhel8
    # special case for operator; all other images follow the pattern
    if [[ $c == "operator" ]] || [[ $c == "operator-metadata" ]]; then 
        d=codeready-workspaces-${c}
    fi 
    ./getLatestImageTags.sh -c ${d} --osbs --pushtoquay="''' + CRW_VERSION + ''' ''' + TAGS + '''" &
done
wait
                            ''')
                        }, 
                        nvr_check: {
                            NEW_NVR = sh (
                                script: "./getLatestImageTags.sh -b ${MIDSTM_BRANCH} --nvr | tee ${WORKSPACE}/LATEST_IMAGES.nvr",
                                returnStdout: true).trim().split( '\n' )
                        }, 
                        get_latest_images: {
                            sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ MIDSTM_BRANCH + '/dependencies/LATEST_IMAGES')
                        }

                        def NEW_QUAY = ""
                        NEW_QUAY = sh (
                            script: "./getLatestImageTags.sh -b ${MIDSTM_BRANCH} --quay | tee ${WORKSPACE}/LATEST_IMAGES.quay",
                            returnStdout: true).trim().split( '\n' )
                            errorOccurred = checkFailure(NEW_QUAY, "Quay", errorOccurred)

                        sh (
                            script: 'curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+MIDSTM_BRANCH+'/product/getTagForImage.sh && chmod +x getTagForImage.sh',
                            returnStdout: true).trim().split( '\n' )

                        // diff quay tag list vs. nvr tag list
                        sh(script: '''#!/bin/bash -xe
${WORKSPACE}/getTagForImage.sh $(cat ${WORKSPACE}/LATEST_IMAGES.quay) -s > ${WORKSPACE}/LATEST_IMAGES.quay.tagsonly
${WORKSPACE}/getTagForImage.sh $(cat ${WORKSPACE}/LATEST_IMAGES.nvr)  -s > ${WORKSPACE}/LATEST_IMAGES.nvr.tagsonly
                        ''', returnStdout: true)
                        def DIFF_LATEST_IMAGES_QUAY_V_NVR = sh (
                            script: 'diff -u0 ${WORKSPACE}/LATEST_IMAGES.{quay,nvr}.tagsonly | grep -v "@@" | grep -v "LATEST_IMAGES" || true',
                            returnStdout: true
                        ).trim()

                        archiveArtifacts fingerprint: false, artifacts:"LATEST_IMAGES*"
                        currentBuild.description="Copied: " + CONTAINERS.trim().replaceAll(" ",", ")
                        if (!DIFF_LATEST_IMAGES_QUAY_V_NVR.equals("")) {
                            // error! quay and nvr versions do not match
                            errorOccurred = errorOccurred + 'Error: Quay & Brew image versions not aligned:\n' + 
                            "=================== QUAY v NVR ===================\n" + 
                            DIFF_LATEST_IMAGES_QUAY_V_NVR + '\n' + 
                            ' Failure!\n'
                            currentBuild.description="Quay/Brew version mismatch!"
                            currentBuild.result = 'FAILURE'
                        }

                        DIFF_LATEST_IMAGES_QUAY_V_STORED = sh (
                            script: 'diff -u0 ${WORKSPACE}/LATEST_IMAGES{,.quay} | grep -v "@@" | grep -v "LATEST_IMAGES" || true',
                            returnStdout: true
                        ).trim()

                        def NEW_QUAY_L=""; NEW_QUAY.each { line -> if (line?.trim()) { NEW_QUAY_L=NEW_QUAY_L+"  ${line}\n" } }
                        def NEW_NVR_L="";  NEW_NVR.each  { line -> if (line?.trim()) { NEW_NVR_L=NEW_NVR_L + "  ${line}\n" } } 
                        echo '''
Quay Images:
''' + NEW_QUAY_L + '''

Brew NVRs:
''' + NEW_NVR_L
                        } // with
                } // wrap 
            } // stage
            if (!errorOccurred.equals("")) {
                echo errorOccurred
            }
        } catch (e) {
            if (!errorOccurred.equals("")) {
                echo errorOccurred
                return
            }
            throw e
        } // try
    } // node
} // timeout

// trigger update_digests job if we have pushed new images that appear in the registry or metadata
node("${buildNode}"){ 
  stage ("Update registries and metadata") {
    sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/'+ MIDSTM_BRANCH + '/product/util.groovy')
    def util = load "${WORKSPACE}/util.groovy"
    echo "currentBuild.result = " + currentBuild.result
    if (!currentBuild.result.equals("ABORTED") && !currentBuild.result.equals("FAILED")) {
        // check if ${WORKSPACE}/LATEST_IMAGES.quay is different from stored LATEST_IMAGES
        // if LATEST_IMAGES files are different, run downstream job, if not, echo warning / set status yellow
        if (!DIFF_LATEST_IMAGES_QUAY_V_STORED.equals("")) {
            println "Scheduling update-digests-in-registries-and-metadata for this update:"
            println DIFF_LATEST_IMAGES_QUAY_V_STORED
            CRW_VERSION = util.getCrwVersion(MIDSTM_BRANCH)
            println "CRW_VERSION = '" + CRW_VERSION + "'"
            build(
                job: 'update-digests-in-registries-and-metadata_' + CRW_VERSION,
                wait: false,
                propagate: false,
                parameters: [
                    [
                    $class: 'StringParameterValue',
                    name: 'token',
                    value: "CI_BUILD"
                    ],
                    [
                    $class: 'StringParameterValue',
                    name: 'cause',
                    value: "push-latest-containers-to-quay+for+" + CONTAINERS.trim().replaceAll(" ","+") + "+by+${BUILD_TAG}"
                    ]
                ]
            )
            currentBuild.description=currentBuild.description+"; update-digests-in-registries-and-metadata triggered"
        } else {
            println "No changes to LATEST_IMAGES; no need to trigger update-digests-in-registries-and-metadata_" + CRW_VERSION
            currentBuild.result = 'UNSTABLE'
            currentBuild.description=currentBuild.description+"; update-digests-in-registries-and-metadata NOT triggered"
        } // if 2
    } // if
  } // stage
} //node

// https://issues.redhat.com/browse/CRW-1011 trigger crw-theia-akamai job 
node("${buildNode}"){ 
  stage ("Enable Akamai CDN support for CRW Theia image") {
    echo "currentBuild.result = " + currentBuild.result
    if (!currentBuild.result.equals("ABORTED") && !currentBuild.result.equals("FAILED")) {
        // if CONTAINERS contains theia
        println "Containers: " + CONTAINERS.trim()
        if (CONTAINERS.trim().equals("theia") || CONTAINERS.trim().matches(".*theia .*")) {
            println "Scheduling crw-theia-akamai"
            build(
                job: 'crw-theia-akamai',
                wait: false,
                propagate: false,
                parameters: [
                    [
                    $class: 'StringParameterValue',
                    name: 'token',
                    value: "CI_BUILD"
                    ],
                    [
                    $class: 'StringParameterValue',
                    name: 'cause',
                    value: "crw-theia-akamai+for+" + CONTAINERS.trim().replaceAll(" ","+") + "+by+${BUILD_TAG}"
                    ]
                ]
            )
            currentBuild.description=currentBuild.description+"; crw-theia-akamai triggered"
        // } else {
        //     println "No theia image update; no need to trigger crw-theia-akamai"
        //     currentBuild.result = 'UNSTABLE'
        //     currentBuild.description=currentBuild.description+"; crw-theia-akamai NOT triggered"
        } // if 2
    } // if
  } // stage
} //node
