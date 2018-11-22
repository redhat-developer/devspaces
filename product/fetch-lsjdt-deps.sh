#!/bin/bash -xe
# script to bootstrap jdt.ls / ls.jdt artifacts so they can be found in Indy

lsjdtVersion="LATEST"
if [[ $1 ]]; then lsjdtVersion=$1; fi

pushd /tmp
    MVN="mvn -U dependency:get -Dtransitive=false"
    MVN="${MVN} -DremoteRepositories=http://oss.sonatype.org/content/repositories/snapshots/"
    MVN="${MVN} -Dversion=${lsjdtVersion} -DgroupId=org.eclipse.che.ls.jdt"

    ${MVN} -DartifactId=jdt.ls.extension.api -Dpackaging=pom -Dmaven.repo.local=/tmp/m2-repo-temp | tee /tmp/m2-log.txt
    lsjdtVersionActual=$(cat /tmp/m2-log.txt | egrep -v "metadata" | grep Downloading | grep "jdt.ls.extension.api" | sed -e "s#.\+/jdt.ls.extension.api-\(.\+\).pom#\1#")
    echo "[INFO] Found jdt.ls.extension.api version ${lsjdtVersionActual} in oss.sonatype.org nexus repo."
    rm -fr /tmp/m2-log.txt /tmp/m2-repo-temp
    echo "[INFO] Fetch artifacts..."
    time ${MVN} -q -DartifactId=jdt.ls.extension.api -Dversion=${lsjdtVersionActual}
    time ${MVN} -q -DartifactId=jdt.ls.extension.api -Dclassifier=sources
    time ${MVN} -q -DartifactId=jdt.ls.extension.product -Dpackaging=tar.gz
popd