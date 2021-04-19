#!/bin/bash -xe
# build a container in brew, then if successful, copy to quay.

# to run for multiple repos checked out locally...
# $➔ for d in $(ls -1 -d stacks-*); do cd $d; { ../buildInBrewCopyToQuay.sh $d; }; cd ..; done
# $➔ for d in $(ls -1 -d plugin-*); do cd $d; { ../buildInBrewCopyToQuay.sh $d; }; cd ..; done

# TODO should we invoke this and commit changes first?
# /path/to/product/getLatestRPM.sh -s "$(pwd)" -r openshift-clients-4 -u http://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/basearch/rhocp/4.7 -a "x86_64 s390x ppc64le" 
# /path/to/product/getLatestRPM.sh -s "$(pwd)" -r helm-3 -u http://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/basearch/ocp-tools/4.7 -a "x86_64 s390x ppc64le" 

IMG=$1

usage() {
  echo "
Build a container in Brew, watch the log, and if successful, copy that container to quay.

Usage: $0 image-name
Example: $0 configbump
"
exit
}

if [[ ! ${IMG} ]]; then usage; fi

brewTaskID=$(rhpkg container-build --nowait | sed -r -e "s#.+: ##" | head -1)
if [[ $brewTaskID ]]; then 
  google-chrome "https://brewweb.engineering.redhat.com/brew/taskinfo?taskID=${brewTaskID}"
  brew watch-logs ${brewTaskID} | tee /tmp/${brewTaskID}.txt

  container="codeready-workspaces-${IMG}-rhel8"
  if [[ $container == *"operator"* ]]; then container="codeready-workspaces-${IMG}"; fi # special case for operator & metadata images

  grep -E "registry.access.redhat.com/codeready-workspaces/.+/images/2.8-[0-9]+" /tmp/${brewTaskID}.txt | \
    grep -E "setting label" | \
    sed -r -e "s@.+(registry.access.redhat.com/codeready-workspaces/)(.+)/images/(2.8-[0-9]+)\"@\2:\3@g" | \
    tr -d "'" | tail -1 && \
  getLatestImageTags.sh -b crw-2.8-rhel-8 --osbs --pushtoquay='2.8 latest' -c $container
fi
