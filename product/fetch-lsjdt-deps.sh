#!/bin/bash -xe
# script to bootstrap jdt.ls / ls.jdt artifacts so they can be found in Indy

lsjdtVersion="0.0.2-SNAPSHOT" # don't use LATEST, it's unpredictable
if [[ $1 ]]; then lsjdtVersion=$1; fi

groupId=org.eclipse.che.ls.jdt
remoteRepositories=https://oss.sonatype.org/content/repositories/snapshots/
#tmpRepo=/tmp/m2-repo-temp
tmpRepo=${HOME}/.m2/repository
pushd /tmp
    rm -fr ${tmpRepo}/org/eclipse/che/ls/jdt/
    MVN="mvn -U dependency:get -Dtransitive=false"
    MVN="${MVN} -DremoteRepositories=${remoteRepositories}"
    MVN="${MVN} -DgroupId=${groupId}  -Dversion=${lsjdtVersion}"

    artifactId=jdt.ls.extension.api
    ${MVN} -DartifactId=${artifactId} -Dpackaging=pom -Dmaven.repo.local=${tmpRepo} | tee /tmp/m2-log.txt
    lsjdtVersionActual=$(cat /tmp/m2-log.txt | egrep -v "metadata" | grep Downloading | grep "${artifactId}" | sed -e "s#.\+/${artifactId}-\(.\+\).pom#\1#")
    rm -fr /tmp/m2-log.txt
    if [[ $lsjdtVersion == "LATEST" ]] && [[ $lsjdtVersionActual != ${lsjdtVersionActual%%-*} ]]; then lsjdtVersion="${lsjdtVersionActual%%-*}-SNAPSHOT"; fi
    echo "[INFO] Found ${artifactId} version ${lsjdtVersion} = ${lsjdtVersionActual} in ${remoteRepositories}"

    echo "[INFO] Fetch ${artifactId} ${lsjdtVersionActual} ..."
    time ${MVN} -q -DartifactId=${artifactId} -Dmaven.repo.local=${tmpRepo} -Dpackaging=jar
    time mvn install:install-file -Dfile=${tmpRepo}/org/eclipse/che/ls/jdt/${artifactId}/${lsjdtVersion}/${artifactId}-${lsjdtVersionActual}.jar \
        -DartifactId=${artifactId} -Dversion=${lsjdtVersion} -DgroupId=${groupId} -Dpackaging=jar
    time ${MVN} -q -DartifactId=${artifactId} -Dmaven.repo.local=${tmpRepo} -Dclassifier=sources -Dpackaging=jar
    time mvn install:install-file -Dfile=${tmpRepo}/org/eclipse/che/ls/jdt/${artifactId}/${lsjdtVersion}/${artifactId}-${lsjdtVersionActual}-sources.jar \
        -DartifactId=${artifactId} -Dversion=${lsjdtVersion} -DgroupId=${groupId} -Dclassifier=sources -Dpackaging=jar

    artifactId=jdt.ls.extension.product
    ${MVN} -DartifactId=${artifactId} -Dpackaging=pom -Dmaven.repo.local=${tmpRepo} | tee /tmp/m2-log.txt
    lsjdtVersionActual=$(cat /tmp/m2-log.txt | egrep -v "metadata" | grep Downloading | grep "${artifactId}" | sed -e "s#.\+/${artifactId}-\(.\+\).pom#\1#")
    rm -fr /tmp/m2-log.txt
    if [[ $lsjdtVersion == "LATEST" ]] && [[ $lsjdtVersionActual != ${lsjdtVersionActual%%-*} ]]; then lsjdtVersion="${lsjdtVersionActual%%-*}-SNAPSHOT"; fi
    echo "[INFO] Found ${artifactId} version ${lsjdtVersion} = ${lsjdtVersionActual} in ${remoteRepositories}"

    echo "[INFO] Fetch ${artifactId} ${lsjdtVersionActual} ..."
    time ${MVN} -q -DartifactId=${artifactId} -Dmaven.repo.local=${tmpRepo} -Dpackaging=tar.gz 
    time mvn install:install-file -Dfile=${tmpRepo}/org/eclipse/che/ls/jdt/${artifactId}/${lsjdtVersion}/${artifactId}-${lsjdtVersionActual}.tar.gz \
        -DartifactId=${artifactId} -Dversion=${lsjdtVersion} -DgroupId=${groupId} -Dpackaging=tar.gz

popd