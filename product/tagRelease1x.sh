#!/bin/bash
#
# script to tag the Che/CRW repos for a given release

if [[ ! $1 ]]; then
	echo "Usage: $0 version-to-tag"
	echo "Example: $0 1.2.2.GA"
	exit 1
else
	TAG="$1"
fi

mkdir -p /tmp/tmp-checkouts
cd /tmp/tmp-checkouts

for d in che-operator; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone git@github.com:eclipse/${d}.git projects_${d}; fi
	cd projects_${d} && git checkout 1.x -q && git pull -q
	git tag ${TAG} && git push origin ${TAG}
	cd ..
done

for d in codeready-workspaces codeready-workspaces-deprecated codeready-workspaces-productization; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone git@github.com:redhat-developer/${d}.git projects_${d}; fi 
	cd projects_${d} && git checkout 6.19.x -q && git pull -q
	git tag ${TAG} && git push origin ${TAG}
	cd ..
done

for d in codeready-workspaces-stacks-node; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone ssh://nboldt@pkgs.devel.redhat.com/containers/${d} containers_${d}; fi
	cd containers_${d} && git checkout codeready-1.0-rhel-7 -q && git pull -q
	git tag -a ${TAG}_RHEL7 -m "${TAG}_RHEL7" && git push origin ${TAG}_RHEL7
	cd ..
done

for d in \
codeready-workspaces codeready-workspaces-operator codeready-workspaces-stacks-cpp \
codeready-workspaces-stacks-dotnet codeready-workspaces-stacks-golang codeready-workspaces-stacks-java \
codeready-workspaces-stacks-node codeready-workspaces-stacks-php codeready-workspaces-stacks-python \
; do
	echo; echo "== $d =="
	if [[ ! -d ${d} ]]; then git clone ssh://nboldt@pkgs.devel.redhat.com/containers/${d} containers_${d}; fi
	cd containers_${d} && git checkout crw-1.2-rhel-8 -q && git pull -q
	git tag -a ${TAG} -m "${TAG}" && git push origin ${TAG}
	cd ..
done

# cleanup
# cd /tmp
# rm -fr /tmp/tmp-checkouts
