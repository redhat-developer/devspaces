#!/usr/bin/env groovy

import groovy.transform.Field

// PARAMETERS for this pipeline:
// def FORCE_BUILD = "false"

// TODO source from eclipse/che-devfile-registry too

@Field String MIDSTM_BRANCH = "crw-2.6-rhel-8" // branch of GH and pkgs.devel repos to sync commits

def MIDSTM_REPO = "redhat-developer/codeready-workspaces" //source repo from which to find and sync commits to pkgs.devel repo
def DWNSTM_REPO = "redhat-developer/codeready-workspaces-images" // dist-git repo to use as target
def DWNSTM_BRANCH = MIDSTM_BRANCH // target branch in dist-git repo, eg., crw-2.5-rhel-8
def SCRATCH = "false"
def PUSH_TO_QUAY = "true"
def QUAY_PROJECT = "devfileregistry" // also used for the Brew dockerfile params
def USE_DIGESTS = "true" // if true, use @sha256:digest in registry; if false, use :tag
def SYNC_FILES="arbitrary-users-patch build devfiles images .gitignore .htaccess LICENSE README.md VERSION"

def OLD_SHA=""
def NEW_SHA=""
def HAS_CHANGED="false"

def buildNode = "s390x-rhel7-beaker" // node label
timeout(120) {
  node("${buildNode}"){ stage "Sync repos"
    wrap([$class: 'TimestamperBuildWrapper']) {
      sh('curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/' + MIDSTM_BRANCH + '/product/util.groovy')
      def util = load "${WORKSPACE}/util.groovy"
      cleanWs()
      CRW_VERSION = util.getCrwVersion(MIDSTM_BRANCH)
      println "CRW_VERSION = '" + CRW_VERSION + "'"
      util.installSkopeo(CRW_VERSION)
      withCredentials([string(credentialsId:'devstudio-release.token', variable: 'GITHUB_TOKEN'),
          file(credentialsId: 'crw-build.keytab', variable: 'CRW_KEYTAB')]) {
        util.bootstrap(CRW_KEYTAB)

        println "########################################################################################################"
        println "##  Clone and update github.com/${MIDSTM_REPO}.git"
        println "########################################################################################################"
        util.cloneRepo("https://github.com/${MIDSTM_REPO}.git", "${WORKSPACE}/targetmid", MIDSTM_BRANCH)
        OLD_SHA = util.getLastCommitSHA("${WORKSPACE}/targetmid")
        SOURCE_DIR="${WORKSPACE}/targetmid/dependencies/che-devfile-registry/"
        TARGET_DIR="${WORKSPACE}/targetdwn/" + util.getCRWLongName(QUAY_PROJECT) + "/"
        util.updateBaseImages(SOURCE_DIR + "build/dockerfiles", DWNSTM_BRANCH, "-f rhel.Dockerfile")
        SOURCE_SHA = util.getLastCommitSHA("${WORKSPACE}/targetmid")
        println "Got SOURCE_SHA in sources folder: " + SOURCE_SHA
        if (OLD_SHA != SOURCE_SHA) { HAS_CHANGED="true" }

        println "########################################################################################################"
        println "##  Sync ${QUAY_PROJECT} to codeready-workspaces-images"
        println "########################################################################################################"
        util.cloneRepo("https://github.com/${DWNSTM_REPO}", "${WORKSPACE}/targetdwn", DWNSTM_BRANCH)
        OLD_SHA = util.getLastCommitSHA("${WORKSPACE}/targetdwn")

        // rsync files to codeready-workspaces-images
        sh('''#!/bin/bash -xe
          SOURCEDIR="''' + SOURCE_DIR + '''"
          TARGETDIR="''' + TARGET_DIR + '''"
          SYNC_FILES="''' + SYNC_FILES + '''"
          [ ! -d ${TARGETDIR} ] && mkdir -p ${TARGETDIR}
          for d in ${SYNC_FILES}; do
            if [[ -f ${SOURCEDIR}/${d} ]]; then
              rsync -azrlt ${SOURCEDIR}/${d} ${TARGETDIR}/${d}
            elif [[ -d ${SOURCEDIR}/${d} ]]; then
              # copy over the dir contents
              rsync -azrlt ${SOURCEDIR}/${d}/* ${TARGETDIR}/${d}/
              # sync the directory and delete from targetdwn if deleted from source
              rsync -azrlt --delete ${SOURCEDIR}/${d}/ ${TARGETDIR}/${d}/
            else
              echo "[WARN] Could not find ${SOURCEDIR}/${d} to sync to ${TARGETDIR}/${d}"
            fi
          done
        ''')

        sh('''#!/bin/bash -xe
          cp -f ''' + SOURCE_DIR + '''build/dockerfiles/rhel.Dockerfile  ''' + TARGET_DIR + '''Dockerfile

          CRW_VERSION="''' + CRW_VERSION_F + '''"
          # apply patches to transform CRW upstream to pkgs.devel version
          sed -i ''' + TARGET_DIR + '''Dockerfile --regexp-extended \
          `# Replace image used for registry with rhel8/httpd-24` \
          -e 's|^ *FROM registry.access.redhat.com/.* AS registry|# &|' \
          -e 's|# *(FROM.*rhel8/httpd.*)|\\1|' \
          `# Strip registry from image references` \
          -e 's|FROM registry.access.redhat.com/|FROM |' \
          -e 's|FROM registry.redhat.io/|FROM |' \
          `# Set arg options: enable USE_DIGESTS and disable BOOTSTRAP` \
          -e 's|ARG USE_DIGESTS=.*|ARG USE_DIGESTS=''' + USE_DIGESTS + '''|' \
          -e 's|ARG BOOTSTRAP=.*|ARG BOOTSTRAP=false|' \
          `# Enable offline build - copy in built binaries` \
          -e 's|# (COPY root-local.tgz)|\\1|' \
          `# only enable rhel8 here -- don't want centos or epel ` \
          -e 's|^ *(COPY .*)/content_set.*repo (.+)|\\1/content_sets_rhel8.repo \\2|' \
          `# Comment out PATCHED_* args from build and disable update_devfile_patched_image_tags.sh` \
          -e 's|^ *ARG PATCHED.*|# &|' \
          -e '/^ *RUN TAG/,+3 s|.*|# &| ' \
          `# Disable intermediate build targets` \
          -e 's|^ *FROM registry AS offline-registry|# &|' \
          -e '/^ *FROM builder AS offline-builder/,+3 s|.*|# &|' \
          -e 's|^[^#]*--from=offline-builder.*|# &|' \
          -e '/COPY --from=builder/a COPY --from=builder /build/resources /var/www/html/resources' \
          `# Enable cache_projects.sh` \
          -e '\\|swap_images.sh|i # Cache projects in CRW \\
COPY ./build/dockerfiles/rhel.cache_projects.sh resources.tgz /tmp/ \\
RUN /tmp/rhel.cache_projects.sh /build/ && rm -rf /tmp/rhel.cache_projects.sh /tmp/resources.tgz \\
'

          METADATA='ENV SUMMARY="Red Hat CodeReady Workspaces ''' + QUAY_PROJECT + ''' container" \\\r
    DESCRIPTION="Red Hat CodeReady Workspaces ''' + QUAY_PROJECT + ''' container" \\\r
    PRODNAME="codeready-workspaces" \\\r
    COMPNAME="''' + QUAY_PROJECT + '''-rhel8" \r
LABEL summary="$SUMMARY" \\\r
      description="$DESCRIPTION" \\\r
      io.k8s.description="$DESCRIPTION" \\\r
      io.k8s.display-name=\"$DESCRIPTION" \\\r
      io.openshift.tags="$PRODNAME,$COMPNAME" \\\r
      com.redhat.component="$PRODNAME-$COMPNAME-container" \\\r
      name="$PRODNAME/$COMPNAME" \\\r
      version="'${CRW_VERSION}'" \\\r
      license="EPLv2" \\\r
      maintainer="Nick Boldt <nboldt@redhat.com>" \\\r
      io.openshift.expose-services="" \\\r
      usage="" \r'

          echo -e "$METADATA" >> ''' + TARGET_DIR + '''Dockerfile

          echo "======= DOWNSTREAM DOCKERFILE =======>"
          cat ''' + TARGET_DIR + '''Dockerfile
          echo "<======= DOWNSTREAM DOCKERFILE ======="
        ''')

        // push changes to codeready-workspaces-images
        util.updateBaseImages(TARGET_DIR, DWNSTM_BRANCH, "--nocommit")
        sh('''#!/bin/bash -xe
          SYNC_FILES="''' + SYNC_FILES + '''"
          cd ${WORKSPACE}/targetdwn
          git add ''' + util.getCRWLongName(QUAY_PROJECT) + '''
          git update-index --refresh  # ignore timestamp updates
          if [[ \$(git diff-index HEAD --) ]]; then # file changed
            cd ''' + TARGET_DIR + '''
            git add Dockerfile ${SYNC_FILES}
            # note this might fail if we're syncing from a tag vs. a branch
            git commit -s -m "[sync] Update from ''' + MIDSTM_REPO + ''' @ ''' + SOURCE_SHA[0..7] + '''" Dockerfile ${SYNC_FILES}
            git push origin ''' + DWNSTM_BRANCH + ''' || true
            NEW_SHA=\$(git rev-parse HEAD) # echo ${NEW_SHA:0:8}
            echo "[sync] Updated pkgs.devel @ ${NEW_SHA:0:8} from ''' + MIDSTM_REPO + ''' @ ''' + SOURCE_SHA[0..7] + '''"
          fi
        ''')
        NEW_SHA = util.getLastCommitSHA("${WORKSPACE}/targetdwn")
        if (OLD_SHA != NEW_SHA) { HAS_CHANGED="true" }

        println "########################################################################################################"
        println "##  Kickoff Sync to downstream job"
        println "########################################################################################################"
        if (HAS_CHANGED == "true" || FORCE_BUILD == "true") {
          SYNC_REPO = util.getCRWLongName(QUAY_PROJECT)
          build(
              job: 'crw-plugins-and-stacks_' + CRW_VERSION,
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
                  value: SYNC_REPO.replaceAll("codeready-workspaces-","") + "+respin+by+${BUILD_TAG}"
                ],
                [
                  $class: 'StringParameterValue',
                  name: 'REPOS',
                  value: "${SYNC_REPO}"
                ],
                [
                  $class: 'StringParameterValue',
                  name: 'FORCE_BUILD',
                  value: "true"
                ],
                [
                  $class: 'StringParameterValue',
                  name: 'SCRATCH',
                  value: "false"
                ]
              ]
            )
        } else {
          println "No changes upstream, nothing to commit"
        }

        NEW_SHA = util.getLastCommitSHA("${WORKSPACE}/targetdwn")
        println "Got NEW_SHA in targetdwn folder: " + NEW_SHA

        if (NEW_SHA.equals(OLD_SHA) && !FORCE_BUILD.equals("true")) {
          currentBuild.result='UNSTABLE'
        }
      } // withCredentials
    } // wrap
  } // node
} // timeout
