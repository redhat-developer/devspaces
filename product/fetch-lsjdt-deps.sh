#!/bin/bash -xe
# script to bootstrap jdt.ls / ls.jdt artifacts so they can be found in Indy

lsjdtVersion="0.0.2-SNAPSHOT" # don't use LATEST, it's unpredictable
if [[ $1 ]]; then lsjdtVersion=$1; fi

export NCL_PROXY="https://${buildContentId}+tracking:${accessToken}@${proxyServer}:${proxyPort}"
# wget proxies
export http_proxy="${NCL_PROXY}"
export https_proxy="${NCL_PROXY}"

groupId=org.eclipse.che.ls.jdt
remoteRepositories=http://oss.sonatype.org/content/repositories/snapshots/
#tmpRepo=/tmp/m2-repo-temp
tmpRepo=${HOME}/.m2/repository
pushd /tmp
    rm -fr ${tmpRepo}/org/eclipse/che/ls/jdt/
    MVN="mvn -U dependency:get -Dtransitive=false"
    MVN="${MVN} -DremoteRepositories=${remoteRepositories}"
    MVN="${MVN} -DgroupId=${groupId}  -Dversion=${lsjdtVersion}"

    artifactId=jdt.ls.extension.api
    wget --server-response ${remoteRepositories}org/eclipse/che/ls/jdt/${artifactId}/${lsjdtVersion}/maven-metadata.xml -O /tmp/mm.xml
    lsjdtVersionActual=$(grep value /tmp/mm.xml | tail -1 | sed -e "s#.*<value>\(.\+\)</value>#\1#" && rm -f /tmp/mm.xml)

    echo "[INFO] Fetch ${artifactId} version ${lsjdtVersion} = ${lsjdtVersionActual} from ${remoteRepositories} ..."
    time ${MVN} -DartifactId=${artifactId} -Dmaven.repo.local=${tmpRepo} -Dpackaging=jar
    time mvn install:install-file -Dfile=${tmpRepo}/org/eclipse/che/ls/jdt/${artifactId}/${lsjdtVersion}/${artifactId}-${lsjdtVersionActual}.jar \
        -DartifactId=${artifactId} -Dversion=${lsjdtVersion} -DgroupId=${groupId} -Dpackaging=jar
    time ${MVN} -DartifactId=${artifactId} -Dmaven.repo.local=${tmpRepo} -Dclassifier=sources -Dpackaging=jar
    time mvn install:install-file -Dfile=${tmpRepo}/org/eclipse/che/ls/jdt/${artifactId}/${lsjdtVersion}/${artifactId}-${lsjdtVersionActual}-sources.jar \
        -DartifactId=${artifactId} -Dversion=${lsjdtVersion} -DgroupId=${groupId} -Dclassifier=sources -Dpackaging=jar

    artifactId=jdt.ls.extension.product
    wget --server-response ${remoteRepositories}org/eclipse/che/ls/jdt/${artifactId}/${lsjdtVersion}/maven-metadata.xml -O /tmp/mm.xml
    lsjdtVersionActual=$(grep value /tmp/mm.xml | tail -1 | sed -e "s#.*<value>\(.\+\)</value>#\1#" && rm -f /tmp/mm.xml)

    echo "[INFO] Fetch ${artifactId} version ${lsjdtVersion} = ${lsjdtVersionActual} from ${remoteRepositories} ..."
    time ${MVN} -DartifactId=${artifactId} -Dmaven.repo.local=${tmpRepo} -Dpackaging=tar.gz 
    time mvn install:install-file -Dfile=${tmpRepo}/org/eclipse/che/ls/jdt/${artifactId}/${lsjdtVersion}/${artifactId}-${lsjdtVersionActual}.tar.gz \
        -DartifactId=${artifactId} -Dversion=${lsjdtVersion} -DgroupId=${groupId} -Dpackaging=tar.gz

popd