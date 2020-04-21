#!/bin/bash

# script to generate a manifest of all the 3rd party deps not built in OSBS, but built in Jenkins or imported from upstream community.

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT"); # echo $SCRIPTPATH

cd /tmp

CRW_VERSION=2.1.1 # arbitrary version label to use when listing containers: 2.0, 2.1, 2.1.1
CRW_BRANCH_TAG=2.1.1.GA # branch or tag must exist in codeready-workspaces-deprecated repo

MANIFEST_FILE=/tmp/manifest.txt
LOG_FILE=/tmp/manifest_log.txt
rm -f ${LOG_FILE} ${MANIFEST_FILE} ${MANIFEST_FILE/.txt/-rpms.txt} ${MANIFEST_FILE/.txt/-mvn.txt} ${MANIFEST_FILE/.txt/-all.txt}

function log () {
	echo "$1" | tee -a ${LOG_FILE}
}
function mnf () {
	echo "$1" | tee -a ${MANIFEST_FILE}
}
function bth () {
	echo "$1" >> ${MANIFEST_FILE}
	echo "$1" | tee -a ${LOG_FILE}
}

function getMavenVar () {
	var=$1
	getMavenVar_return=$(cat ${LOG_FILE} | grep "<${var}>" | sed -e "s#.*<${var}>\(.\+\)</${var}>.*#\1#" | uniq | head -1)
	log "[INFO] ${var} = ${getMavenVar_return}"
}

function npmList() {
	prefix="$1"
	for dep in $(npm list | sed -e "s#[├└─┬│ ]\+##g" -e "s#deduped##g" | sort | uniq | sed -e "s#@#:#g"); do
		echo "$prefix$dep" >> ${MANIFEST_FILE}
	done
}

function dotnetList() {
	prefix="$1"
	cd /tmp
	wget https://raw.githubusercontent.com/OmniSharp/omnisharp-roslyn/v${DOTNET_LS_VERSION}/tools/packages.config -q -O - | grep "<package " | \
sed -e "s#.\+<package id=\"\(.\+\)\" version=\"\(.\+\)\".\+#${prefix}\1:\2#g" | tee -a ${MANIFEST_FILE}
}

function phpList() {
	prefix="$1"
	for dep in $(php composer.phar show -t | sed -e "s#|^# || ^#g" -e "s#\(.\+\) PHP .\+#\1#g" -e "s#[\`-├└─┬-]\+##g" -e "s#\^[\ \t]\+##" -e "s#[\ \t]*\([a-z/]\+\) \([0-9.]\+\)#\1:\2#g" | sort | uniq); do
		echo "$prefix$dep" >> ${MANIFEST_FILE}
	done
}

function pythonList() {
	prefix="$1"
	for dep in $(pip list --format freeze | sed -e "s#==#:#g"); do
		echo "$prefix$dep" >> ${MANIFEST_FILE}
	done
}

# wget dockerfiles
# grep for YUM install or FROM, plus dependency versions
function logDockerDetails ()
{
	# echo "Fetch $1 ..."
	theFileURL="$1"
	theFile=/tmp/curl.tmp
	curl -sSL $theFileURL > $theFile
	prefix="$2"
	log "$(cat $theFile | egrep -i "FROM|yum|rh-|INSTALL|COPY|ADD|curl|_VERSION" | egrep -v "opt/rh|yum clean all|yum-config-manager|^( *)#|useradd|entrypoint.sh|gopath")"
	mnf "$(cat $theFile | egrep "^FROM" | sed -e "s#^FROM #${prefix}#g")"
	rm -f $theFile
}

###############################################################################################################

rm -f ${LOG_FILE} ${MANIFEST_FILE}

log "1. Generate a list of maven instructions to fetch 3rd party language server dependencies" 
if [[ ! -d codeready-workspaces-deprecated ]]; then 
  git clone git@github.com:redhat-developer/codeready-workspaces-deprecated.git
fi
pushd codeready-workspaces-deprecated
	git checkout ${CRW_BRANCH_TAG} && cd stacks/dependencies
	for p in */pom.xml; do 
		log "" 
		log " == ${p%/pom.xml} ==" 
		log "$(egrep "executable|arg|zip|tar|_VERSION" $p | egrep -v "target>|delete|mkdir" | sed -e "s#                               ##")"
	done
popd
log ""
# NOTE: don't delete this checkout yet, we need it for later.

log "2. Define list of upstream containers & RPMs pulled into them from https://pkgs.devel.redhat.com/cgit/?q=codeready-workspaces "
for d in \
codeready-workspaces \
codeready-workspaces-operator codeready-workspaces-operator-metadata \
\
codeready-workspaces-jwtproxy codeready-workspaces-machineexec \
codeready-workspaces-devfileregistry codeready-workspaces-pluginregistry \
codeready-workspaces-pluginbroker-metadata codeready-workspaces-plugin-artifacts \
codeready-workspaces-plugin-kubernetes codeready-workspaces-plugin-openshift \
codeready-workspaces-imagepuller \
\
codeready-workspaces-theia-dev \
codeready-workspaces-theia codeready-workspaces-theia-endpoint \
\
codeready-workspaces-stacks-cpp codeready-workspaces-stacks-dotnet codeready-workspaces-stacks-golang \
codeready-workspaces-stacks-java codeready-workspaces-stacks-node codeready-workspaces-stacks-php \
codeready-workspaces-stacks-python codeready-workspaces-plugin-java11 \
; do
	if [[ $d == "codeready-workspaces" ]]; then
		containerName=${d##containers/}-server-rhel8-container
	else
		containerName=${d##containers/}-rhel8-container
	fi
	# echo $containerName
	log ""
	log "== ${d} (crw-2.0-rhel-8) =="
	logDockerDetails http://pkgs.devel.redhat.com/cgit/containers/${d}/plain/Dockerfile?h=crw-2.0-rhel-8 "containers/${containerName/}:${CRW_VERSION}/"
done
bth ""

log "3. Other than the above, all artifacts used in CodeReady Workspaces are now built in RH Central CI Jenkins:"
log "https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/view/CRW_CI/view/Builds/"
log "https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/view/CRW_CI/view/Pipelines/"
log ""
log "See also latest build architecture diagram & development documentation:"
log "https://docs.google.com/presentation/d/1R9tr67pDMk3UVUbvN7vBJbJCYGlUsO2ZPcXbdaoOvTs/edit#slide=id.g4ac34a3cdd_0_0"
log "https://github.com/redhat-developer/codeready-workspaces-productization/tree/master/devdoc"

##################################

getMavenVar "GOLANG_IMAGE_VERSION"; GOLANG_IMAGE_VERSION="${getMavenVar_return}"
getMavenVar "GOLANG_LS_VERSION"; GOLANG_LS_VERSION="${getMavenVar_return}"
getMavenVar "NODEJS_IMAGE_VERSION"; NODEJS_IMAGE_VERSION="${getMavenVar_return}"
log ""
log " == golang =="
log ""
log "4c-1. Install golang go deps: go-language-server@${GOLANG_LS_VERSION}"
log ""
cd /tmp
export GOPATH=/tmp/go-deps-tmp/
rm -fr /tmp/go-deps-tmp
mkdir -p go-deps-tmp && cd go-deps-tmp

if [[ ! -x /usr/bin/go ]]; then echo "Error: install golang to run this script: sudo yum -y install golang"; fi

# run the same set of go get -v commands in the pom:
grep "go get -v" /tmp/codeready-workspaces-deprecated/stacks/dependencies/golang/pom.xml > todos.txt
while read p; do
	# if you want more detailed output and logging, comment the nest 1 line and uncomment the following 4 lines
	log "  ${p%%;*}"; ${p%%;*}
	#log " == ${p%%;*} ==>"
	#${p%%;*} 2>&1 | tee -a ${LOG_FILE}
	#log "<== ${p%%;*} =="
	#log ""
done <todos.txt
# now we can delete the codeready-workspaces-deprecated checkout folder as we don't need its contents anymore
rm -fr /tmp/codeready-workspaces-deprecated

# now get the SHAs used in each github repo cloned locally
mnf "codeready-workspaces-stacks-golang-container:${CRW_VERSION}/go-language-server:${GOLANG_LS_VERSION}"
for d in $(find . -name ".git" | sort); do
	g=${d%%/.git}
	pushd ${g} >/dev/null
	mnf "  codeready-workspaces-stacks-golang-container:${CRW_VERSION}/${g##./src/}:$(git rev-parse HEAD)"
	popd >/dev/null
done
mnf ""
rm -fr /tmp/go-deps-tmp /tmp/go-build*

log ""
log "4c-2. Install golang npm deps: go-language-server@${GOLANG_LS_VERSION}"
log ""
cd /tmp
rm -fr /tmp/npm-deps-tmp
mkdir -p npm-deps-tmp && cd npm-deps-tmp
npm install --prefix /tmp/npm-deps-tmp/ go-language-server@${GOLANG_LS_VERSION} | tee -a ${LOG_FILE}
log ""
npm list >> ${LOG_FILE}
mnf "codeready-workspaces-stacks-golang-container:${CRW_VERSION}/go-language-server:${GOLANG_LS_VERSION}"
for cn in golang; do
	npmList "  codeready-workspaces-stacks-${cn}-container:${CRW_VERSION}/"
	mnf ""
done
rm -fr /tmp/npm-deps-tmp

##################################

getMavenVar "NODEJS_IMAGE_VERSION"; NODEJS_IMAGE_VERSION="${getMavenVar_return}"
getMavenVar "TYPERSCRIPT_VERSION"; TYPERSCRIPT_VERSION="${getMavenVar_return}"
getMavenVar "TYPESCRIPT_LS_VERSION"; TYPESCRIPT_LS_VERSION="${getMavenVar_return}"
log ""
log " == node =="
log""
log "4d. Install node deps: typescript@${TYPERSCRIPT_VERSION} typescript-language-server@${TYPESCRIPT_LS_VERSION}"
log ""
cd /tmp
rm -fr /tmp/npm-deps-tmp
mkdir -p npm-deps-tmp && cd npm-deps-tmp
npm install --prefix /tmp/npm-deps-tmp/ typescript@${TYPERSCRIPT_VERSION} typescript-language-server@${TYPESCRIPT_LS_VERSION} | tee -a ${LOG_FILE}
log ""
npm list >> ${LOG_FILE}
for cn in node; do
	mnf "codeready-workspaces-stacks-${cn}-container:${CRW_VERSION}/typescript:${TYPERSCRIPT_VERSION}"
	mnf "codeready-workspaces-stacks-${cn}-container:${CRW_VERSION}/typescript-language-server:${TYPESCRIPT_LS_VERSION}"
	npmList "  codeready-workspaces-stacks-${cn}-container:${CRW_VERSION}/"
	mnf ""
done
rm -fr /tmp/npm-deps-tmp

##################################

getMavenVar "PHP_LS_VERSION"; PHP_LS_VERSION="${getMavenVar_return}"
getMavenVar "WEBDEVOPS_IMAGE"; WEBDEVOPS_IMAGE="${getMavenVar_return}"
getMavenVar "XDEBUG_BUILDER_IMAGE"; XDEBUG_BUILDER_IMAGE="${getMavenVar_return}"
log ""
log " == php =="
log""
log "4e. Install php deps: "
log ""
log "$ php composer.phar require jetbrains/phpstorm-stubs:dev-master"
log "$ php composer.phar require felixfbecker/language-server:${PHP_LS_VERSION}"
cd /tmp
rm -fr /tmp/php-deps-tmp
mkdir -p php-deps-tmp && cd php-deps-tmp

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'e0012edf3e80b6978849f5eff0d4b4e4c79ff1609dd1e613307e16318854d24ae64f26d17af3ef0bf7cfb710ca74755a') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"

php composer.phar require -d /tmp/php-deps-tmp jetbrains/phpstorm-stubs:dev-master | tee -a ${LOG_FILE}
log ""
php composer.phar require -d /tmp/php-deps-tmp felixfbecker/language-server:${PHP_LS_VERSION} | tee -a ${LOG_FILE}
# php composer.phar run-script --working-dir=vendor/felixfbecker/language-server parse-stubs # does not install new deps, so don't need to run this
php composer.phar show -t >> ${LOG_FILE}
log ""
php composer.phar show >> ${LOG_FILE}
mnf "codeready-workspaces-stacks-php-container:${CRW_VERSION}/jetbrains/phpstorm-stubs:dev-master"
mnf "codeready-workspaces-stacks-php-container:${CRW_VERSION}/felixfbecker/language-server:${PHP_LS_VERSION}"
phpList "  codeready-workspaces-stacks-php-container:${CRW_VERSION}/"
mnf ""
cd /tmp
rm -fr /tmp/php-deps-tmp

##################################

getMavenVar "PYTHON_IMAGE_VERSION"; PYTHON_IMAGE_VERSION="${getMavenVar_return}"
getMavenVar "PYTHON_LS_VERSION"; PYTHON_LS_VERSION="${getMavenVar_return}"
log ""
log " == python =="
log ""
log "4f. Install python deps: pip install python-language-server[all]==${PYTHON_LS_VERSION}"
log ""
cd /tmp
rm -fr /tmp/python-deps-tmp
mkdir -p python-deps-tmp && cd python-deps-tmp

python3 -m virtualenv env
source env/bin/activate
which python
pip install python-language-server[all]==${PYTHON_LS_VERSION} | tee -a ${LOG_FILE}
log ""
pip list >> ${LOG_FILE}
mnf "codeready-workspaces-stacks-python-container:${CRW_VERSION}/python-language-server[all]:${PYTHON_LS_VERSION}"
pythonList "  codeready-workspaces-stacks-python-container:${CRW_VERSION}/"
deactivate
rm -fr /tmp/python-deps-tmp


##################################
# Now call the other get-3rd-party-deps*.sh scripts, and merge results into one overall manifest
##################################


##################################

log""
log "5. Collect RPM deps"
cd /tmp
${SCRIPTPATH}/${0/manifests/rpms}

##################################

log ""
log "6. Collect MVN deps"
log ""
cd /tmp
${SCRIPTPATH}/${0/manifests/mvn}

##################################

log ""
log "7. Collect Theia deps (NEW for CRW 2.0)"
log ""
cd /tmp
${SCRIPTPATH}/${0/manifests/theia}

##################################

# merge logs
cat ${MANIFEST_FILE/.txt/-rpms.txt} ${MANIFEST_FILE/.txt/-mvn.txt} ${MANIFEST_FILE/.txt/-theia.txt} ${MANIFEST_FILE} > ${MANIFEST_FILE/.txt/-all.txt}

##################################

log "Short manifest is in file: ${MANIFEST_FILE}"
log "Long log is in file: ${LOG_FILE}"
log ""
log "Overall manifest is in file: ${MANIFEST_FILE/.txt/-all.txt}"
log ""

##################################
