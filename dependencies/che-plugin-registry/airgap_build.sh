#!/bin/bash -ex
#
# Builds this container, including locally fetched plugins and replaces references to docker/quay/RHCC with specified container registry
# 
# see also https://github.com/eclipse/che/issues/14693
# 

if [[ $1 == "nightly" ]]; then
	nightly="nightly"
	now=`date +%Y%m%d-%H%M`
elif [[ $1 ]]; then
	cat Dockerfile   | sed -e "s%#.*RUN ./list_containers.sh%RUN ./list_containers.sh%" > Dockerfile.2
	cat Dockerfile.2 | sed -e "s%myquay.mycorp.com%${1}%" > Dockerfile
	nightly="${1%%.*}" # first section of the URL replacement
	now="${nightly}-`date +%Y%m%d-%H%M`" # append timestamp
else
	echo "Must specify URL of internal registry to use, eg., $0 myquay.mycorp.com"
	echo "To fetch plugins but not do registry substitutions, use $0 nightly"
	echo "To push to quay, use $0 myquay.mycorp.com --push"
	exit 1
fi

now=`date +%Y%m%d-%H%M`
docker build . -t quay.io/nickboldt/airgap-che-plugin-registry:${nightly} --no-cache --squash
docker tag quay.io/nickboldt/airgap-che-plugin-registry:{${nightly},${now}}

if [[ $2 == "--push" ]]; then
	for d in ${nightly} ${now}; do
		docker push quay.io/nickboldt/airgap-che-plugin-registry:${d} &
	done
	wait
else
	echo "To push these containers, do this:

"
	for d in ${nightly} ${now}; do
		echo "docker push quay.io/nickboldt/airgap-che-plugin-registry:${d} &"
	done
fi

