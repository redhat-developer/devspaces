#!/bin/bash

set -e
MIDSTM_BRANCH=""
SCRIPT_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))

# script to generate a manifest of all the 3rd party deps not built in OSBS, but built in Jenkins or imported from upstream community.

checkdependencies ()
{
# see also https://gitlab.cee.redhat.com/codeready-workspaces/crw-jenkins/-/blob/master/jobs/DS_CI/Releng/get-3rd-party-deps-manifests.jenkinsfile (live sources)
# or https://github.com/redhat-developer/devspaces-images/blob/devspaces-3-rhel-8/crw-jenkins/jobs/DS_CI/Releng/get-3rd-party-deps-manifests.jenkinsfile (external copy)

# rpm installed dependencies
# rhpkg krb5-workstation tree golang php-devel php-json python3-six python3-pip
for rpm in rhpkg kinit tree pyvenv; do
  rpm -qf $(which $rpm) || { echo "$rpm not installed!"; exit 1; }; echo "-----"
done
go version || { echo "go not installed!"; exit 1; }; echo "-----"
php --version || { echo "php not installed!"; exit 1; }; echo "-----"
python3 --version || { echo "python3 not installed!"; exit 1; }; echo "-----"

# skopeo >1.1, installed via rpm or other method
skopeo -v || { echo "skopeo not installed!"; exit 1; }; echo "-----"

# yq (the jq wrapper installed via python + pip, not the standalone project)
jq --version || { echo "jq not installed!"; exit 1; }; echo "-----"
yq --version || { echo "yq not installed!"; exit 1; }; echo "-----"

# node 12 and yarn 1.17 or newer (rpm or other install method)
echo -n "node "; node --version || { echo "node not installed!"; exit 1; }; echo "-----"
echo -n "npm "; npm --version || { echo "npm not installed!"; exit 1; }; echo "-----"
echo -n "yarn "; yarn --version || { echo "yarn not installed!"; exit 1; }; echo "-----"

# openjdk 11 and maven 3.6 (rpm or other install method)
mvn --version || { echo "mvn not installed!"; exit 1; }; echo "-----"
exit
}

usage () 
{
    echo "Usage: $0 -b devspaces-3.y-rhel-8 -v 3.y.0"
	echo ""
	echo "To check if all dependencies are installed: "
	echo "  $0 --check-dependencies"
    exit
}

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT"); # echo $SCRIPTPATH
phases=""
# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    '-v') CSV_VERSION="$2"; shift 1;;
    '--check-dependencies') checkdependencies;;
    '-h') usage;;
    *) phases="${phases} $1 ";;
  esac
  shift 1
done

cd /tmp || exit

if [[ ! ${MIDSTM_BRANCH} ]]; then usage; fi
# phases 2 and 3 have been removed 
if [[ ! ${phases} ]]; then phases=" 1 4 5 6 7 8 9 "; fi

if [[ ! ${CSV_VERSION} ]]; then 
  CSV_VERSION=$(curl -sSLo - https://raw.githubusercontent.com/redhat-developer/devspaces-operator/${MIDSTM_BRANCH}/manifests/devspaces.csv.yaml | yq -r .spec.version)
fi

DS_BRANCH_TAG=${CSV_VERSION}

if [[ ! ${WORKSPACE} ]]; then WORKSPACE=${SCRIPT_DIR}; fi
mkdir -p "${WORKSPACE}/${CSV_VERSION}"

MANIFEST_FILE="${WORKSPACE}/${CSV_VERSION}/manifest.txt"
LOG_FILE="${WORKSPACE}/${CSV_VERSION}/manifest_log.txt"
rm -f ${LOG_FILE} ${MANIFEST_FILE} ${MANIFEST_FILE/.txt/-all.txt}

for d in mvn rpms; do rm -f ${WORKSPACE}/${CSV_VERSION}/${d}/manifest-${d}.txt; done

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
	buildsh="${2:-build.sh}" # collect vars from a specific build_*.sh script
	# parse the specific file and export the correct variables
	pushd /tmp/devspaces-images >/dev/null || exit 1
		for p in ${dir}/build/${buildsh}; do 
			grep -E "export " $p | grep -E -v "SCRIPT_DIR|PATH=" | sed -r -e "s@#.+@@g" > "${p}.tmp"
			# shellcheck disable=SC1090
			. "${p}.tmp" && rm -f ${p}.tmp
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
	for dep in $(php composer.phar show -f json | jq -r '.installed[] | [.name,.version] | @csv' | tr -d "\""); do
		echo "$prefix${dep/,/:}" >> ${MANIFEST_FILE}
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
	echo "$(cat $theFile | grep -E "^FROM" | sed -e "s#^FROM #${prefix}#g")" \
		| tee -a ${MANIFEST_FILE/.txt/-containers-base-images-only.txt}

	echo "$(cat $theFile | grep -E "^FROM" | sed -e "s#^FROM #${prefix}#g")" \
		| tee -a ${MANIFEST_FILE/.txt/-containers-binaries-extras.txt}
	echo "$(cat $theFile | grep -E -i "FROM|yum|rh-|INSTALL|COPY|ADD|curl|_VERSION" | grep -E -v "opt/rh|yum clean all|yum-config-manager|^( *)#|useradd|entrypoint.sh|gopath")" \
		| tee -a ${MANIFEST_FILE/.txt/-containers-binaries-extras.txt}
	echo \
		| tee -a ${MANIFEST_FILE/.txt/-containers-binaries-extras.txt}
	rm -f $theFile
}

###############################################################################################################

rm -f ${LOG_FILE} ${MANIFEST_FILE}

if [[ ${phases} == *"1"* ]] || [[ ${phases} == *"4"* ]] || [[ ${phases} == *"5"* ]] || [[ ${phases} == *"6"* ]]; then
	log "1a. Check out 3rd party language server dependencies builder repo (will collect variables later)" 
	cd /tmp
	if [[ ! -d devspaces-images ]]; then
		git clone -b ${DS_BRANCH_TAG} --depth 1 --single-branch https://$GITHUB_TOKEN:x-oauth-basic@github.com/redhat-developer/devspaces-images.git
	fi
	pushd devspaces-images>/dev/null
		git config --global push.default matching
		git config --global hub.protocol https
		git checkout ${DS_BRANCH_TAG} || { echo "Tag or branch ${DS_BRANCH_TAG} does not exist! Create it before running this script."; exit 1; }
	popd >/dev/null
	log ""
	# NOTE: don't delete this checkout yet, we need it for later.
fi

if [[ ${phases} == *"1"* ]]; then

	rm -fr ${MANIFEST_FILE/.txt/-containers-binaries-extras.txt} ${MANIFEST_FILE/.txt/-containers-base-images-only.txt}
	log "1b. Define list of upstream containers & RPMs pulled into them from https://pkgs.devel.redhat.com/cgit/?q=devspaces "
	for d in \
	devspaces-code \
	devspaces-configbump \
	devspaces-dashboard \
	devspaces-devfileregistry \
	devspaces-idea \
	\
	devspaces-imagepuller \
	devspaces-machineexec \
	devspaces-operator \
	devspaces-operator-bundle \
	devspaces-pluginregistry \
	\
	devspaces-server \
	devspaces-traefik \
	devspaces-udi \
	; do
		if [[ $d == "devspaces" ]]; then
			containerName=${d##containers/}-server-rhel8-container
		else
			containerName=${d##containers/}-rhel8-container
		fi
		# echo $containerName
		log ""
		log "== ${d} (${MIDSTM_BRANCH}) =="
		logDockerDetails https://pkgs.devel.redhat.com/cgit/containers/${d}/plain/Dockerfile?h=${MIDSTM_BRANCH} "containers/${containerName}:${CSV_VERSION}/"
	done
	bth ""

	log "Short container list (base images only):        ${MANIFEST_FILE/.txt/-containers-base-images-only.txt}"
	log "Long container list (with dockerfile snippets): ${MANIFEST_FILE/.txt/-containers-binaries-extras.txt}"
	log ""
	log "1c. Other than the above, all artifacts used in Red Hat OpenShift Dev Spaces (formerly "
	log "    Red Hat CodeReady Workspaces) Workspaces are now built in RH Central CI Jenkins:"
	log "https://main-jenkins-csb-crwqe.apps.ocp-c1.prod.psi.redhat.com/"
	log ""
	log "See also latest build architecture diagram & development documentation:"
	log "https://docs.google.com/presentation/d/1R9tr67pDMk3UVUbvN7vBJbJCYGlUsO2ZPcXbdaoOvTs/edit#slide=id.g4ac34a3cdd_0_0"
	log "https://github.com/redhat-developer/devtools-productization/tree/main/codeready-workspaces"
fi

##################################

if [[ ${phases} == *"4"* ]]; then
	cd /tmp
	log ""
	log " == php =="
	log""
	log "4. Install php deps: "
	if [[ ! $(which php) ]]; then sudo yum -y -q install php-devel php-json || true; fi
	if [[ ! $(which php) ]]; then echo "Error: install php to run this script: sudo yum -y install php-devel php-json"; exit 1; fi
	getBashVars devspaces-udi build_php.sh
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
	php composer.phar show >> ${LOG_FILE}
	mnf "devspaces-udi-container:${CSV_VERSION}/jetbrains/phpstorm-stubs:dev-master"
	mnf "devspaces-udi-container:${CSV_VERSION}/felixfbecker/language-server:v${PHP_LS_VERSION}"
	phpList "  devspaces-udi-container:${CSV_VERSION}/"
	mnf ""
	cd /tmp
	rm -fr /tmp/php-deps-tmp
fi

##################################

if [[ ${phases} == *"5"* ]]; then
	cd /tmp
	log ""
	log " == python =="
	log ""
	log "5. Install python deps: pip install python-language-server[all]==${PYTHON_LS_VERSION}"
	pyrpms="python3-six python3-pip"
	if [[ ! $(which python3) ]] || [[ ! $(pydoc3 modules | grep venv) ]]; then sudo yum install -y -q $pyrpms || true; fi
	if [[ ! $(which python3) ]] || [[ ! $(pydoc3 modules | grep venv) ]]; then echo "Error: install $pyrpms to run this script: sudo yum -y install $pyrpms"; exit 1; fi
	getBashVars devspaces-udi build_python.sh
	for d in \
		"PYTHON_IMAGE" \
		"PYTHON_LS_VERSION" \
		; do
		log " * $d = ${!d}"
	done
	log ""
	cd /tmp
	rm -fr /tmp/python-deps-tmp
	mkdir -p python-deps-tmp && cd python-deps-tmp

	/usr/bin/python3 -m venv env
	source env/bin/activate
	/usr/bin/python3 -m pip install --upgrade pip
	{ /usr/bin/python3 -m pip install python-language-server[all]==${PYTHON_LS_VERSION} | tee -a ${LOG_FILE}; } || true
	log ""
	{ /usr/bin/python3 -m pip list >> ${LOG_FILE}; } || true
	mnf "devspaces-udi-container:${CSV_VERSION}/python-language-server[all]:${PYTHON_LS_VERSION}"
	pythonList "  devspaces-udi-container:${CSV_VERSION}/"
	deactivate
	rm -fr /tmp/python-deps-tmp
fi

# now we can delete the devspaces-images checkout folder as we don't need its contents anymore
rm -fr /tmp/devspaces-images


##################################
# Now call the other get-3rd-party-deps*.sh scripts, and merge results into one overall manifest
##################################


##################################

if [[ ${phases} == *"6"* ]]; then
	log""
	log "6. Collect RPM deps"
	cd /tmp
	${SCRIPTPATH}/${0/manifests/rpms} -v "${CSV_VERSION}" -b "${MIDSTM_BRANCH}"
fi

##################################

if [[ ${phases} == *"7"* ]]; then
	log ""
	log "7. Collect MVN deps"
	log ""
	cd /tmp
	${SCRIPTPATH}/${0/manifests/mvn} -v "${CSV_VERSION}" -b "${MIDSTM_BRANCH}"
fi

##################################

if [[ ${phases} == *"8"* ]]; then
	log ""
	log "8. Collect NPM deps"
	log ""
	cd /tmp
	${SCRIPTPATH}/${0/manifests/npm} -v "${CSV_VERSION}" -b "${MIDSTM_BRANCH}"
fi

##################################

# append mvn, npm logs to the short manifest
if [[ ${phases} == *"7"* ]] || [[ ${phases} == *"8"* ]]; then
	for d in mvn npm; do
		if [[ -f ${WORKSPACE}/${CSV_VERSION}/${d}/manifest-${d}.txt ]]; then
			cat ${WORKSPACE}/${CSV_VERSION}/${d}/manifest-${d}.txt >> ${MANIFEST_FILE}
		fi
	done
fi

# append mvn, npm logs to the long manifest, but NOT the RPMs (See CRW-3250)
touch ${MANIFEST_FILE/.txt/-all.txt}
if [[ ${phases} == *"6"* ]] || [[ ${phases} == *"7"* ]] || [[ ${phases} == *"8"* ]]; then
	for d in mvn npm; do
		if [[ -f ${WORKSPACE}/${CSV_VERSION}/${d}/manifest-${d}.txt ]]; then
			cat ${WORKSPACE}/${CSV_VERSION}/${d}/manifest-${d}.txt >> ${MANIFEST_FILE/.txt/-all.txt}
		fi
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
