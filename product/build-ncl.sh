#!/bin/bash -xe
# script to build eclipse-che in #projectncl

##########################################################################################
# apply patches - dont forget to \$ so that mvn variables are not interpreted by bash 
##########################################################################################

# path relative to root since we run this script as ./product/build-ncl.sh
#patch -p2 <product/foo.patch

# fix dashboard - migrate to Yarn
# git cherry-pick --keep-redundant-commits 3005b907815118c8ebef75a09d51798e0b052077

# don't build dashboard from source; include from upstream binary in http://oss.sonatype.org/content/repositories/snapshots/
includeDashboardFromSource=0

# remove docs from assembly-main - requires using '-P!docs' profile
# git cherry-pick --keep-redundant-commits c1fa62ae86f976d97247e726458f6e25ccf0611f

##########################################################################################
# enable support for CI builds
##########################################################################################

#set version & compute qualifier from best available in Indy
# or use commandline overrides for version and suffix
version=6.13.0
suffix="" # normally we compute this from version of org/eclipse/che/depmgt/maven-depmgt-pom but can override if needed
upstreamPom=org/eclipse/che/depmgt/maven-depmgt-pom # usually use depmgt/maven-depmgt-pom but can also align to che-parent for codeready-workspaces build
INDY=""

# read commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-v') version="$2"; shift 1;; #eg., 6.12.0
    '-s') suffix="$2"; shift 1;; # eg., redhat-00007
    '-dv') includeDashboardVersion="$2"; shift 1;; # eg., 6.11.1 or 6.13.0-SNAPSHOT
    '-up') upstreamPom="$2"; shift 1;; # eg., 6.11.1 or 6.13.0-SNAPSHOT
    '-PROFILES') PROFILES="$2"; shift 1;; # override default profiles
    '-MVNFLAGS') MVNFLAGS="$2"; shift 1;; # add more mvn flags
    '-INDY') INDY="$2"; shift 1;; # override for default INDY URL
    *) OTHER="${OTHER} $1"; shift 0;; 
  esac
  shift 1
done

if [[ ! ${suffix} ]]; then # compute it from version of org/eclipse/che/depmgt/maven-depmgt-pom
  tmpfile=/tmp/maven-metadata-${version}.html
  # external 1: http://indy.cloud.pnc.engineering.redhat.com/api/group/static/org/eclipse/che/depmgt/maven-depmgt-pom/ or /che/che-parent/
  # external 2: http://indy.cloud.pnc.engineering.redhat.com/api/content/maven/group/builds-untested+shared-imports+public/org/eclipse/che/depmgt/maven-depmgt-pom/
  UPSTREAM_POM="api/content/maven/group/builds-untested+shared-imports+public/${upstreamPom}/maven-metadata.xml"
  if [[ ! ${INDY} ]]; then 
    INDY=http://indy.project-newcastle.svc.cluster.local
  fi
  if [[ ! $(wget ${INDY} -q -S 2>&1 | egrep "200|302|OK") ]]; then
    INDY=http://pnc-indy-branch-nightly.project-newcastle.svc.cluster.local
  fi
  if [[ ! $(wget ${INDY} -q -S 2>&1 | egrep "200|302|OK") ]]; then
    INDY=http://pnc-indy-master-nightly.project-newcastle.svc.cluster.local
  fi
  if [[ ! $(wget ${INDY} -q -S 2>&1 | egrep "200|302|OK") ]]; then
    echo "[WARNING] Could not load org/eclipse/che/depmgt/maven-depmgt-pom from Indy"
  fi
  wget ${INDY}/${UPSTREAM_POM} -O ${tmpfile}
  suffix=$(grep ${version} ${tmpfile} | grep "<latest>" | egrep '.redhat-[0-9]{5}' | sed -e "s#.\+>\([0-9.]\+\.\)\(redhat-[0-9]\{5\}\).*#\2#" | sort -r | head -1)
  rm -f ${tmpfile}
fi

if [[ ! ${includeDashboardVersion} ]]; then
  includeDashboardVersion=${version}-SNAPSHOT
fi

# replace pme version with the version from upstream parent pom, so we can resolve parent pom version 
# and all artifacts in che-* builds use the same qualifier
# TODO: might be able to skip this step once PNC 1.4 / PME 3.1 is rolled out:
# see https://docs.engineering.redhat.com/display/JPC/PME+3.1
# temp w/ timestamp: 6.12.0.t20180917-201638-873-redhat-00001
# temp w/o timestamp: 6.12.0.temporary-redhat-00001-47358abd
# persistent: 6.12.0.redhat-00001-ec28abe6
# pmeVersionSHA=$(git describe --tags)
# pmeSuffix=${pmeVersion#${version}.}; echo $suffix
if [[ ${suffix} ]]; then 
  for d in $(find . -name pom.xml); do sed -i "s#\(version>\)${version}.*\(</version>\)#\1${version}.${suffix}\2#g" $d; done
  for d in $(find . -name pom.xml); do sed -i "s#\(<che.\+version>\)${version}.*\(</che.\+version>\)#\1${version}.${suffix}\2#g" $d; done
  for d in $(find . -name pom.xml); do sed -i "s#\(<version>${version}\)-SNAPSHOT#\1.${suffix}#g" $d; done
  mvn versions:set -DnewVersion=${version}.${suffix}
  mvn versions:update-parent "-DparentVersion=${version}.${suffix}" -DallowSnapshots=false
  for d in $(find . -maxdepth 1 -name pom.xml); do sed -i "s#\(<.\+\.version>.\+\)-SNAPSHOT#\1.${suffix}#g" $d; done
fi

##########################################################################################
# set up npm environment
##########################################################################################

uname -a
go version
node -v
npm version
mvn -v

export NCL_PROXY="http://${buildContentId}+tracking:${accessToken}@${proxyServer}:${proxyPort}"
# wget proxies
export http_proxy="${NCL_PROXY}"
export https_proxy="${NCL_PROXY}"

export nodeDownloadRoot=http://nodejs.org:80/dist/
export npmDownloadRoot=http://registry.npmjs.org:80/npm/-/
export npmRegistryURL=http://registry.npmjs.org:80/
export YARN_REGISTRY=http://registry.yarnpkg.com:80/

npm config set https-proxy ${NCL_PROXY}
npm config set https_proxy ${NCL_PROXY}
npm config set proxy ${NCL_PROXY}
#silent, warn, info, verbose, silly
npm config set loglevel warn 
# do not use maxsockets 2 or build will stall & die
npm config set maxsockets 80 
npm config set fetch-retries 10
npm config set fetch-retry-mintimeout 60000
npm config set registry ${npmRegistryURL}
# npm config list


if [[ $includeDashboardFromSource -gt 0 ]]; then
  # workaround for lack of https support and inability to see github.com as a result
  mkdir -p /tmp/phantomjs/
  pushd /tmp/phantomjs/
    # previously mirrored from https://github.com/Medium/phantomjs/releases/download/v2.1.1/phantomjs-2.1.1-linux-x86_64.tar.bz2
    time wget -q http://download.jboss.org/jbosstools/updates/requirements/node/phantomjs/phantomjs-2.1.1-linux-x86_64.tar.bz2
  popd

  pushd dashboard
    time npm install phantomjs-prebuilt
    export PATH=${PATH}:`pwd`/node_modules/phantomjs-prebuilt/bin

    time npm install yarn
    PATH=${PATH}:`pwd`/node_modules/yarn/bin
    yarn config set registry ${YARN_REGISTRY} --global
    yarn config set YARN_REGISTRY ${YARN_REGISTRY} --global

    yarn config set proxy ${NCL_PROXY} --global
    yarn config set yarn-proxy ${NCL_PROXY} --global
    yarn config set yarn_proxy ${NCL_PROXY} --global

    yarn config set https-proxy false --global
    yarn config set https_proxy false --global
    yarn config list
    yarn install --frozen-lockfile --no-lockfile --pure-lockfile --ignore-optional --non-interactive --production=false
  popd
fi

##########################################################################################
# configure maven build 
##########################################################################################

if [[ ! ${PROFILES} ]]; then PROFILES=' -Pfast,native,!docker,!docs'; fi

MVNFLAGS="${MVNFLAGS} -V -ff -B -e -Dskip-enforce -DskipTests -Dskip-validate-sources -Dfindbugs.skip -DskipIntegrationTests=true"
MVNFLAGS="${MVNFLAGS} -Dmdep.analyze.skip=true -Dmaven.javadoc.skip -Dgpg.skip -Dorg.slf4j.simpleLogger.showDateTime=true"
MVNFLAGS="${MVNFLAGS} -Dorg.slf4j.simpleLogger.dateTimeFormat=HH:mm:ss "
MVNFLAGS="${MVNFLAGS} -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn"
MVNFLAGS="${MVNFLAGS} -DnodeDownloadRoot=${nodeDownloadRoot} -DnpmDownloadRoot=${npmDownloadRoot}"
MVNFLAGS="${MVNFLAGS} -DnpmRegistryURL=${npmRegistryURL}"

if [[ $includeDashboardFromSource ]]; then
  MVNFLAGS="${MVNFLAGS} -DYARN_REGISTRY=${YARN_REGISTRY}"
fi

if [[ $includeDashboardVersion ]]; then
  if [[ ${includeDashboardVersion} == *"-SNAPSHOT" ]]; then snapOrRel="snapshots"; else snapOrRel="releases"; fi # echo $snapOrRel
  wget -q http://oss.sonatype.org/content/repositories/${snapOrRel}/org/eclipse/che/dashboard/che-dashboard-war/${includeDashboardVersion}/maven-metadata.xml -O /tmp/mm.xml
  cheDashboardVersion=$(grep value /tmp/mm.xml | tail -1 | sed -e "s#.*<value>\(.\+\)</value>#\1#" && rm -f /tmp/mm.xml)
  if [[ ! ${cheDashboardVersion} ]]; then cheDashboardVersion=${includeDashboardVersion}; fi # fallback to 6.13.0-SNAPSHOT if not resolved
  MVNFLAGS="${MVNFLAGS} -Dche.dashboard.version=${cheDashboardVersion}"
fi

##########################################################################################
# run maven build 
##########################################################################################

mvn clean deploy ${PROFILES} ${MVNFLAGS}
