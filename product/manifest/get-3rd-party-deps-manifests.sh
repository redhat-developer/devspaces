#!/bin/bash

set -e

# script to generate a manifest of all the 3rd party deps not built in OSBS, but built in Jenkins or imported from upstream community.

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT"); # echo $SCRIPTPATH
phases=""
# commandline args
for key in "$@"; do
  case $key in
    '--crw'*) getLatestImageFlag="$1";;
    *) phases="${phases} $1 ";;
  esac
  shift 1
done
if [[ ! ${phases} ]]; then phases=" 1 2 3 4 5 6 7 8 "; fi

cd /tmp

# compute version from latest operator paackage.yaml, eg., 2.2.0
# TODO when we switch to OCP 4.6 bundle format, extract this version from another place
CSV_VERSION="$1"
if [[ ! ${CSV_VERSION} ]]; then 
  CSV_VERSION=$(curl -sSLo - https://raw.githubusercontent.com/redhat-developer/codeready-workspaces-operator/master/controller-manifests/codeready-workspaces.package.yaml | yq .channels[0].currentCSV -r | sed -r -e "s#crwoperator.v##")
fi

CRW_BRANCH_TAG=${CSV_VERSION}.GA 

if [[ ! ${WORKSPACE} ]]; then WORKSPACE=/tmp; fi
mkdir -p "${WORKSPACE}/${CSV_VERSION}"

MANIFEST_FILE="${WORKSPACE}/${CSV_VERSION}/manifest.txt"
LOG_FILE="${WORKSPACE}/${CSV_VERSION}/manifest_log.txt"
rm -f ${LOG_FILE} ${MANIFEST_FILE} ${MANIFEST_FILE/.txt/-all.txt}
for d in mvn rpms theia; do rm -f ${WORKSPACE}/${CSV_VERSION}/${d}/manifest-${d}.txt; done

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

function getBashVars () {
	dir="$1" # script dir
	# parse the specific file and export the correct variables
	pushd /tmp/codeready-workspaces-deprecated >/dev/null || exit 1
		for p in ${dir}/build.sh; do 
			egrep "export " $p | egrep -v "SCRIPT_DIR" | sed -r -e "s@#.+@@g" > ${p}.tmp
			. ${p}.tmp && rm -f ${p}.tmp
		done
	popd >/dev/null || exit 1
}

function npmList() {
	prefix="$1"
	for dep in $(npm list | sed -e "s#[├└─┬│ ]\+##g" -e "s#deduped##g" | sort | uniq | sed -e "s#@#:#g" || true); do
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
	for dep in $(/usr/bin/python3 -m pip list --format freeze | sed -e "s#==#:#g"); do
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
	prefix="$2" # echo prefix="$2"
	log "$(cat $theFile | egrep -i "FROM|yum|rh-|INSTALL|COPY|ADD|curl|_VERSION" | egrep -v "opt/rh|yum clean all|yum-config-manager|^( *)#|useradd|entrypoint.sh|gopath")"
	mnf "$(cat $theFile | egrep "^FROM" | sed -e "s#^FROM #${prefix}#g")"
	rm -f $theFile
}

###############################################################################################################

rm -f ${LOG_FILE} ${MANIFEST_FILE}

if [[ ${phases} == *"1"* ]] || [[ ${phases} == *"2"* ]] || [[ ${phases} == *"3"* ]] || [[ ${phases} == *"4"* ]] || [[ ${phases} == *"5"* ]] || [[ ${phases} == *"6"* ]]; then
	log "1a. Check out 3rd party language server dependencies builder repo (will collect variables later)" 
	cd /tmp
	if [[ ! -d codeready-workspaces-deprecated ]]; then 
	git clone git@github.com:redhat-developer/codeready-workspaces-deprecated.git
	fi
	pushd codeready-workspaces-deprecated >/dev/null
		git checkout ${CRW_BRANCH_TAG} || { echo "Tag or branch ${CRW_BRANCH_TAG} does not exist! Create it before running this script."; exit 1; }
	popd >/dev/null
	log ""
	# NOTE: don't delete this checkout yet, we need it for later.
fi

if [[ ${phases} == *"1"* ]]; then
	log "1b. Define list of upstream containers & RPMs pulled into them from https://pkgs.devel.redhat.com/cgit/?q=codeready-workspaces "
	for d in \
	codeready-workspaces \
	codeready-workspaces-operator codeready-workspaces-operator-metadata \
	\
	codeready-workspaces-jwtproxy codeready-workspaces-machineexec \
	codeready-workspaces-devfileregistry codeready-workspaces-pluginregistry \
	codeready-workspaces-pluginbroker-metadata codeready-workspaces-plugin-artifacts \
	codeready-workspaces-plugin-kubernetes codeready-workspaces-plugin-openshift \
	codeready-workspaces-plugin-java11 codeready-workspaces-plugin-java8 \
	codeready-workspaces-imagepuller \
	\
	codeready-workspaces-theia-dev \
	codeready-workspaces-theia codeready-workspaces-theia-endpoint \
	\
	codeready-workspaces-stacks-cpp codeready-workspaces-stacks-dotnet \
	codeready-workspaces-stacks-golang codeready-workspaces-stacks-php \
	; do
		if [[ $d == "codeready-workspaces" ]]; then
			containerName=${d##containers/}-server-rhel8-container
		else
			containerName=${d##containers/}-rhel8-container
		fi
		# echo $containerName
		log ""
		log "== ${d} (crw-2.2-rhel-8) =="
		logDockerDetails http://pkgs.devel.redhat.com/cgit/containers/${d}/plain/Dockerfile?h=crw-2.2-rhel-8 "containers/${containerName}:${CSV_VERSION}/"
	done
	bth ""

	log "1c. Other than the above, all artifacts used in CodeReady Workspaces are now built in RH Central CI Jenkins:"
	log "https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/view/CRW_CI/view/Builds/"
	log "https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/view/CRW_CI/view/Pipelines/"
	log ""
	log "See also latest build architecture diagram & development documentation:"
	log "https://docs.google.com/presentation/d/1R9tr67pDMk3UVUbvN7vBJbJCYGlUsO2ZPcXbdaoOvTs/edit#slide=id.g4ac34a3cdd_0_0"
	log "https://github.com/redhat-developer/codeready-workspaces-productization/tree/master/devdoc"
fi

##################################

if [[ ${phases} == *"2"* ]]; then
	log ""
	log " == golang =="
	log ""
	log "2a. Install golang go deps: go-language-server@${GOLANG_LS_VERSION}"
	if [[ ! -x /usr/bin/go ]]; then echo "Error: install golang to run this script: sudo yum -y install golang"; exit 1; fi
	getBashVars golang
	for d in \
		"GOLANG_IMAGE_VERSION" \
		"GOLANG_LINT_VERSION" \
		"GOLANG_LS_OLD_DEPS" \
		"GOLANG_LS_VERSION" \
		"NODEJS_IMAGE_VERSION" \
		; do
		log " * $d = ${!d}"
	done
	log ""
	cd /tmp
	export GOPATH=/tmp/go-deps-tmp/
	rm -fr /tmp/go-deps-tmp
	mkdir -p go-deps-tmp && cd go-deps-tmp

	# run the same set of go get -v commands in the build.sh script:
	egrep "go get -v|go build -o" /tmp/codeready-workspaces-deprecated/golang/build.sh > todos.txt
	while read p; do
		# if you want more detailed output and logging, comment the next 1 line and uncomment the following 4 lines
		log "  ${p%%;*}"; ${p%%;*} || true
		#log " == ${p%%;*} ==>"
		#${p%%;*} 2>&1 | tee -a ${LOG_FILE}
		#log "<== ${p%%;*} =="
		#log ""
	done <todos.txt
	egrep "GOLANG_LINT_VERSION" /tmp/codeready-workspaces-deprecated/golang/build.sh > todos.txt
	. todos.txt
	rm -f todos.txt

	# now get the SHAs used in each github repo cloned locally
	mnf "codeready-workspaces-stacks-golang-container:${CSV_VERSION}/go-language-server:${GOLANG_LS_VERSION}"
	for d in $(find . -name ".git" | sort); do
		g=${d%%/.git}
		pushd ${g} >/dev/null
		mnf "  codeready-workspaces-stacks-golang-container:${CSV_VERSION}/${g##./src/}:$(git rev-parse HEAD)"
		popd >/dev/null
	done
	mnf ""
	rm -fr /tmp/go-deps-tmp /tmp/go-build*

	log ""
	log "2b. Install golang npm deps: go-language-server@${GOLANG_LS_VERSION}"
	if [[ ! $(which npm) ]]; then echo "Error: install nodejs and npm to run this script: sudo yum -y install nodejs npm"; exit 1; fi
	log ""
	cd /tmp
	rm -fr /tmp/npm-deps-tmp
	mkdir -p npm-deps-tmp && cd npm-deps-tmp
	{ npm install --prefix /tmp/npm-deps-tmp/ go-language-server@${GOLANG_LS_VERSION} | tee -a ${LOG_FILE}; } || true
	log ""
	{ npm list >> ${LOG_FILE}; } || true
	mnf "codeready-workspaces-stacks-golang-container:${CSV_VERSION}/go-language-server:${GOLANG_LS_VERSION}"
	npmList "  codeready-workspaces-stacks-golang-container:${CSV_VERSION}/"
	mnf ""
	rm -fr /tmp/npm-deps-tmp

	cd /tmp
	log ""
	log " == kamel =="
	log ""
	log "2c. kamel is built from go sources with no additional requirements"
	getBashVars kamel
	for d in \
		"GOLANG_IMAGE_VERSION" \
		"KAMEL_VERSION" \
		; do
		log " * $d = ${!d}"
	done
	log ""
fi

##################################

if [[ ${phases} == *"3"* ]]; then
	cd /tmp
	log ""
	log " == node10 (plugin-java8 container) =="
	log""
	log "3. Install node10 deps: typescript@${TYPERSCRIPT_VERSION} typescript-language-server@${TYPESCRIPT_LS_VERSION}"
	if [[ ! $(which npm) ]]; then echo "Error: install nodejs and npm to run this script: sudo yum -y install nodejs npm"; exit 1; fi
	getBashVars node10
	for d in \
		"NODEJS_IMAGE_VERSION" \
		"NODEMON_VERSION" \
		"TYPERSCRIPT_VERSION" \
		"TYPESCRIPT_LS_VERSION" \
		; do
		log " * $d = ${!d}"
	done
	log ""
	cd /tmp
	rm -fr /tmp/npm-deps-tmp
	mkdir -p npm-deps-tmp && cd npm-deps-tmp
	{ npm install --prefix /tmp/npm-deps-tmp/ typescript@${TYPERSCRIPT_VERSION} typescript-language-server@${TYPESCRIPT_LS_VERSION} | tee -a ${LOG_FILE}; } || true
	log ""
	{ npm list >> ${LOG_FILE}; } || true
	mnf "codeready-workspaces-plugin-java8-container:${CSV_VERSION}/typescript:${TYPERSCRIPT_VERSION}"
	mnf "codeready-workspaces-plugin-java8-container:${CSV_VERSION}/typescript-language-server:${TYPESCRIPT_LS_VERSION}"
	npmList "  codeready-workspaces-plugin-java8-container:${CSV_VERSION}/"
	mnf ""
	rm -fr /tmp/npm-deps-tmp
fi

##################################

if [[ ${phases} == *"4"* ]]; then
	cd /tmp
	log ""
	log " == php =="
	log""
	log "4. Install php deps: "
	if [[ ! $(which php) ]]; then echo "Error: install php to run this script: sudo yum -y install php-devel"; exit 1; fi
	getBashVars php
	for d in \
		"PHP_LS_VERSION" \
		"PHP_LS_IMAGE" \
		"PHP_XDEBUG_IMAGE" \
		; do
		log " * $d = ${!d}"
	done
	log ""
	log "$ php composer.phar require jetbrains/phpstorm-stubs:dev-master"
	log "$ php composer.phar require felixfbecker/language-server:${PHP_LS_VERSION}"
	cd /tmp
	rm -fr /tmp/php-deps-tmp
	mkdir -p php-deps-tmp && cd php-deps-tmp

	php --version # need something newer than 5.5.9 - https://github.com/composer/composer/issues/4792
	curl -sSL https://getcomposer.org/installer > /tmp/installer && php /tmp/installer || exit 1
	php composer.phar require -d /tmp/php-deps-tmp jetbrains/phpstorm-stubs:dev-master | tee -a ${LOG_FILE}
	log ""
	php composer.phar require -d /tmp/php-deps-tmp felixfbecker/language-server:${PHP_LS_VERSION} | tee -a ${LOG_FILE}
	# php composer.phar run-script --working-dir=vendor/felixfbecker/language-server parse-stubs # does not install new deps, so don't need to run this
	php composer.phar show -t >> ${LOG_FILE}
	log ""
	php composer.phar show >> ${LOG_FILE}
	mnf "codeready-workspaces-stacks-php-container:${CSV_VERSION}/jetbrains/phpstorm-stubs:dev-master"
	mnf "codeready-workspaces-stacks-php-container:${CSV_VERSION}/felixfbecker/language-server:${PHP_LS_VERSION}"
	phpList "  codeready-workspaces-stacks-php-container:${CSV_VERSION}/"
	mnf ""
	cd /tmp
	rm -fr /tmp/php-deps-tmp
fi

##################################

if [[ ${phases} == *"5"* ]]; then
	cd /tmp
	log ""
	log " == python (plugin-java8 container) =="
	log ""
	log "5. Install python deps: pip install python-language-server[all]==${PYTHON_LS_VERSION}"
	if [[ ! $(which python3) ]] || [[ ! $(pydoc modules | grep virtualenv) ]]; then echo "Error: install python3-six and python3-pip python-virtualenv to run this script: sudo yum -y install python3-six python3-pip python-virtualenv"; exit 1; fi
	getBashVars python
	for d in \
		"PYTHON_IMAGE_VERSION" \
		"PYTHON_LS_VERSION" \
		; do
		log " * $d = ${!d}"
	done
	log ""
	cd /tmp
	rm -fr /tmp/python-deps-tmp
	mkdir -p python-deps-tmp && cd python-deps-tmp

	python3 -m virtualenv env
	source env/bin/activate
	which python
	/usr/bin/python3 -m pip install --upgrade pip
	{ /usr/bin/python3 -m pip install python-language-server[all]==${PYTHON_LS_VERSION} | tee -a ${LOG_FILE}; } || true
	log ""
	{ /usr/bin/python3 -m pip list >> ${LOG_FILE}; } || true
	mnf "codeready-workspaces-plugin-java8-container:${CSV_VERSION}/python-language-server[all]:${PYTHON_LS_VERSION}"
	pythonList "  codeready-workspaces-plugin-java8-container:${CSV_VERSION}/"
	deactivate
	rm -fr /tmp/python-deps-tmp
fi

# now we can delete the codeready-workspaces-deprecated checkout folder as we don't need its contents anymore
rm -fr /tmp/codeready-workspaces-deprecated


##################################
# Now call the other get-3rd-party-deps*.sh scripts, and merge results into one overall manifest
##################################


##################################

if [[ ${phases} == *"6"* ]]; then
	log""
	log "6. Collect RPM deps"
	cd /tmp
	${SCRIPTPATH}/${0/manifests/rpms} -v "${CSV_VERSION}" "${getLatestImageFlag}"
fi

##################################

if [[ ${phases} == *"7"* ]]; then
	log ""
	log "7. Collect MVN deps"
	log ""
	cd /tmp
	${SCRIPTPATH}/${0/manifests/mvn} "${CSV_VERSION}"
fi

##################################

if [[ ${phases} == *"8"* ]]; then
	log ""
	log "8. Collect Theia deps"
	log ""
	cd /tmp
	${SCRIPTPATH}/${0/manifests/theia} "${CSV_VERSION}"
fi

##################################

# merge logs
touch ${MANIFEST_FILE/.txt/-all.txt}
if [[ ${phases} == *"6"* ]] || [[ ${phases} == *"7"* ]] || [[ ${phases} == *"8"* ]]; then
	for d in rpms mvn theia; do 
		cat ${WORKSPACE}/${CSV_VERSION}/${d}/manifest-${d}.txt >> ${MANIFEST_FILE/.txt/-all.txt}
	done
fi
cat ${MANIFEST_FILE} >> ${MANIFEST_FILE/.txt/-all.txt}

##################################

log "Short manifest is in file: ${MANIFEST_FILE}"
log "Long log is in file: ${LOG_FILE}"
log ""
log "Overall manifest is in file: ${MANIFEST_FILE/.txt/-all.txt}"
log ""

##################################
