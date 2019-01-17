#!/bin/bash -xe
# script apply patches/changes to upstream eclipse che so we can build it in Jenkins

CHE_path=$1

# disable docs from assembly main and root pom
perl -0777 -p -i -e 's|(\ +<dependency>.*?<\/dependency>)| ${1} =~ /<artifactId>che-docs<\/artifactId>/?"":${1}|gse' ${CHE_path}/assembly/assembly-main/pom.xml
perl -0777 -p -i -e 's|(\ +<dependencySet>.*?<\/dependencySet>)| ${1} =~ /<include>org.eclipse.che.docs:che-docs<\/include>/?"":${1}|gse' ${CHE_path}/assembly/assembly-main/src/assembly/assembly.xml
perl -0777 -p -i -e 's|(\ +<dependency>.*?<\/dependency>)| ${1} =~ /<artifactId>che-docs<\/artifactId>/?"":${1}|gse' ${CHE_path}/pom.xml
