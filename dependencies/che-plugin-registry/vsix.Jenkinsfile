#!/usr/bin/env groovy

// build params
//branchToBuildPlugin - extension branch (default master)
//extensionPath - URL to extension repo
//publishDestinationAddress - full address for the endpoint, on which the extension should be published
//publishDestinationDir - end folder for the plugin (after /vscode/3rdparty)

import groovy.transform.Field

@Field String SOURCE_VERSION

def installNPM(){
    def nodeHome = tool 'nodejs-12.18.2'
    env.PATH="${nodeHome}/bin:${env.PATH}"
    sh "node --version; npm --version"
}

def getShaVersion(repo) {
    def sha = sh script: "git --git-dir=${repo}/.git rev-parse HEAD", returnStdout: true
    return sha.substring(0, 6)
}

def archiveSources(sourceDir) {
    if (SOURCE_VERSION) {
        sh "rm -rf ${sourceDir}/.git"
        sh "tar -czvf ${sourceDir}-${SOURCE_VERSION}-sources.tar.gz ${sourceDir}"
    } else {
        // will this ever be called? 
        currentBuild.result = 'ABORTED'
        buildDesc="No sources version set: ${SOURCE_VERSION} !"
        currentBuild.description=buildDesc
        error(buildDesc)
    }
}

def ifTagExists(repo, tag) {
    def exists = sh script: "git ls-remote --tags ${repo} | grep refs/tags/${tag} ", returnStatus: true
    echo "${exists}"
    return exists==0
}

def archiveTypescriptSources(branchToBuildPlugin, extensionFolder) {
    checkout([$class: 'GitSCM',
              branches: [[name: "${branchToBuildPlugin}"]],
              doGenerateSubmoduleConfigurations: false,
              poll: true,
              extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "typescript"]],
              submoduleCfg: [],
              userRemoteConfigs: [[url: "https://github.com/Microsoft/vscode"]]])
    sh "rm -rf typescript/.git ${extensionFolder}/.git"
    sh "tar -czvf ${extensionFolder}-${branchToBuildPlugin}-sources.tar.gz typescript ${extensionFolder}"
    sh "rm -rf typescript"
}

def buildJavaExtension(branchToBuildPlugin, extensionFolder) {
    checkout([$class: 'GitSCM',
              branches: [[name: "${branchToBuildPlugin}"]],
              doGenerateSubmoduleConfigurations: false,
              poll: true,
              extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "java-debug"]],
              submoduleCfg: [],
              userRemoteConfigs: [[url: "https://github.com/Microsoft/java-debug"]]])

    installNPM()
    archiveSources("java-debug")
    archiveSources(extensionFolder)
    sh "cd ${extensionFolder} && sudo npm install -g vsce gulp && npm install && npx gulp build_server && vsce package"
}

def buildPhpDebug(branchToBuildPlugin, extensionFolder) {
    sh "sed -i 's/\"version\": \"0.0.0-development\",/\"version\": \"${branchToBuildPlugin}\",/g' ${extensionFolder}/package.json"
    archiveSources(extensionFolder)
    installNPM()
    sh "cd ${extensionFolder} && sudo npm install -g vsce gulp && npm install && npm run build && vsce package"
}

def buildVscodePython(branchToBuildPlugin, extensionFolder) {
    installNPM()
    // do we need any of these rpms too? llvm-toolset clang clang-libs clang-tools-extra git-clang-format
    sh "sudo yum -y install python36 python3-six python3-pip platform-python-pip \
        curl wget bzip2 sudo \
        gdb make cmake gcc gcc-c++"
    sh "sudo /usr/bin/python3 -m pip install --upgrade pip"
    buildNumber = branchToBuildPlugin.substring(branchToBuildPlugin.lastIndexOf('.') + 1)
    echo "${buildNumber}"
    sh "cd ${extensionFolder} && sudo npm install -g vsce gulp && npm ci && gulp updateBuildNumber --buildNumber ${buildNumber} && rm -rf node_modules"
    archiveSources(extensionFolder)
    sh "cd ${extensionFolder} && npm ci && gulp installPythonLibs && gulp prePublishBundle && vsce package"
}

def buildDefault(extensionFolder) {
    archiveSources(extensionFolder)
    installNPM()
    sh "cd ${extensionFolder} && sudo npm install -g vsce gulp && npm install && vsce package"
}

def buildCheIncubator(branchToBuildPlugin, extensionFolder) {
    if (extensionFolder.contains("typescript")) {
        archiveTypescriptSources(branchToBuildPlugin, extensionFolder)
    }
    sh "ls -l"
    sh "cd ${extensionFolder} && ./build.sh"
}

def buildEclipseCdt(extensionFolder) {
    archiveSources(extensionFolder)
    installNPM()
    sh "cd ${extensionFolder} && npm install -g vsce && yarn && yarn build && vsce package"
}

def buildClangVscode(extensionFolder) {
    sh "ls -l"
    sh "cp -r ${extensionFolder}/clang-tools-extra/clangd/clients/clangd-vscode clangd-vscode"
    archiveSources("clangd-vscode")
    installNPM()
    sh "cd ${extensionFolder} && ls -l && cd clang-tools-extra/clangd/clients/clangd-vscode && npm install -g vsce && npm install && npm run package"
}

def buildNodeDebug(extensionFolder) {
    archiveSources(extensionFolder)
    installNPM()
    sh "cd ${extensionFolder} && npm install && yarn package"
}

def buildAtlascode(branchToBuildPlugin, extensionFolder) {
    // libsecret is required for Atlascode
    sh "sudo yum -y install libsecret libsecret-dev"
    archiveSources(extensionFolder)
    installNPM()
    sh """\
    cd ${extensionFolder} && \
    npm install -g vsce && \
    npm -no-git-tag-version --allow-same-version -f version ${branchToBuildPlugin} && \
    npm install && \
    vsce package --baseContentUrl https://bitbucket.org/atlassianlabs/atlascode/src/main/
    """
}

timeout(120) {
    node("rhel7||rhel7-8gb||rhel7-16gb||rhel7-releng"){ stage "Build ${publishDestinationDir} / ${branchToBuildPlugin} from ${extensionPath}"
        cleanWs()
        def buildDesc=""

        // check for dummy values and quit immediately if found
        if (
                publishDestinationDir.contains("CHANGE_ME") || publishDestinationDir.contains("your-extension-name") || 
                branchToBuildPlugin.contains("CHANGE_ME") || branchToBuildPlugin.contains("x.y.z") ||
                extensionPath.contains("CHANGE_ME") || extensionPath.contains("https://github.com/owner/project")
            ) {
            currentBuild.result = 'ABORTED'
            buildDesc="Invalid parameters, please set publishDestinationDir, branchToBuildPlugin, and extensionPath to real values."
            currentBuild.description=buildDesc
            error(buildDesc)
        } else {

            // remove trailing slash if exists
            if ("${extensionPath}".endsWith('/')) {
                extensionPath = extensionPath.substring(0, extensionPath.length() - 1)
            }
            echo "extension path: ${extensionPath}"
            def extensionFolder = "${extensionPath}".substring("${extensionPath}".lastIndexOf('/') + 1)
            echo "extension folder: ${extensionFolder}"

            //branch is assumed to be a tag, and we must check if it is reachable
            def checkoutRef
            if (ifTagExists(extensionPath, branchToBuildPlugin)) {
                checkoutRef = "refs/tags/" + branchToBuildPlugin
            } else if (ifTagExists(extensionPath, "v" + branchToBuildPlugin)) {
                checkoutRef = "refs/tags/v" + branchToBuildPlugin
            } else {
                checkoutRef = branchToBuildPlugin
            }
            echo "branch: ${checkoutRef}"

            currentBuild.description="Building ${publishDestinationDir} / ${branchToBuildPlugin} from ${extensionPath} ..."
            if (checkoutRef.contains("master")) {
                checkout([$class: 'GitSCM',
                        branches: [[name: "${checkoutRef}"]],
                        doGenerateSubmoduleConfigurations: false,
                        poll: true,
                        extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${extensionFolder}"],
                                    [$class: 'CloneOption', depth: 1, noTags: false, reference: '', shallow: true]],
                        submoduleCfg: [],
                        userRemoteConfigs: [[url: "${extensionPath}"]]])
            } else {
                checkout([$class: 'GitSCM',
                        branches: [[name: "${checkoutRef}"]],
                        doGenerateSubmoduleConfigurations: false,
                        poll: true,
                        extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "${extensionFolder}"]],
                        submoduleCfg: [],
                        userRemoteConfigs: [[url: "${extensionPath}"]]])
            }

            SOURCE_VERSION = "${checkoutRef}".equals("${branchToBuildPlugin}") ? getShaVersion(extensionFolder) : "${branchToBuildPlugin}"
            echo "source version: ${SOURCE_VERSION}"

            if (extensionPath.contains("github.com/che-incubator/")) {
                buildCheIncubator(branchToBuildPlugin, extensionFolder)
            } else if (extensionPath.contains("https://github.com/eclipse-cdt/cdt-vscode") || extensionPath.contains("https://github.com/eclipse-cdt/cdt-gdb-vscode")) {
                buildEclipseCdt(extensionFolder)
            } else if (extensionPath.contains("https://github.com/llvm/llvm-project")) {
                buildClangVscode(extensionFolder)
            } else if (extensionPath.contains("https://github.com/microsoft/vscode-python")) {
                buildVscodePython(branchToBuildPlugin, extensionFolder)
            } else if (extensionPath.contains("https://github.com/microsoft/vscode-java-debug")) {
                buildJavaExtension(branchToBuildPlugin, extensionFolder)
            } else if (extensionPath.contains("https://github.com/felixfbecker/vscode-php-debug")) {
                buildPhpDebug(branchToBuildPlugin, extensionFolder)
            } else if (extensionPath.equals("https://github.com/microsoft/vscode-node-debug")) {
                buildNodeDebug(extensionFolder)
            } else if (extensionPath.equals("https://bitbucket.org/atlassianlabs/atlascode")) {
                buildAtlascode(branchToBuildPlugin, extensionFolder)
            } else {
                buildDefault(extensionFolder)
            }

            buildStatusCode = sh script:'''#!/bin/bash -xe
            find ./ -name '*.vsix*' -exec mv {}  .  \\;
            if [[ "''' + checkoutRef + '''" != *"refs/tags/"* ]]; then
                for file in *.vsix; do 
                    mv "${file}" "${file%.vsix}-''' + SOURCE_VERSION + '''.vsix";
                done
            fi
            ''', returnStatus: true

            // check that sources were archived
            def sourceExists = sh script: '''#!/bin/bash -xe
            find . -name "*-sources.tar.gz" | egrep "./"
            ''', returnStatus: true

            if (sourceExists > 0) {
                currentBuild.result = 'ABORTED'
                buildDesc="Missing sources.tar.gz for ${publishDestinationDir} / ${branchToBuildPlugin} !"
                currentBuild.description=buildDesc
                error(buildDesc)
            }

            archiveArtifacts artifacts: '*.vsix, *-sources.tar.gz', fingerprint: true

            currentBuild.description="Waiting for input to push: ${publishDestinationDir} / ${branchToBuildPlugin} ..."
            input (message: "proceed with publish?")

            if (publishDestinationAddress && publishDestinationDir ) {
                echo "beginning publishing process"
                sh "mkdir --parents /tmp/${publishDestinationDir} && find ./ -name '*.vsix' -exec mv {}  /tmp/${publishDestinationDir}  \\;"
                sh "find ./ -name '*-sources.tar.gz' -exec mv {}  /tmp/${publishDestinationDir}  \\;"
                sh "ls -l /tmp/${publishDestinationDir}"

                sh "rsync -arz --protocol=28 /tmp/./${publishDestinationDir} ${publishDestinationAddress}"
            }
            currentBuild.description="${publishDestinationDir} / ${branchToBuildPlugin} from ${extensionPath}"
        }
    }
}