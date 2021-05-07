#!/bin/bash

#che7 containers
CONTAINERS="
eclipse/che-server:nightly 
eclipse/che-keycloak:nightly 
quay.io/eclipse/che-devfile-registry:nightly 
quay.io/eclipse/che-plugin-registry:nightly 
centos/postgresql-96-centos7:latest 
registry.access.redhat.com/ubi8-minimal:8.0 
"

# registry prefix to use instead (eg., artifact repo behind firewall) 
REGPREFIX=quay.io/nickboldt/airgap-
#replacement tag for all containers
# if nightly or latest, ImagePullPolicy defaults to Always instead of PullIfPresent to ensure freshness
TAG=nightly

for container in $CONTAINERS; do
  docker pull -q $container;
  containerName=${container##*/}; containerName=${containerName%%:*}
  echo "Push $container to ${REGPREFIX}${containerName}:${TAG} ..."
  docker tag $container ${REGPREFIX}${containerName}:${TAG}
  docker push ${REGPREFIX}${containerName}:${TAG} &
done

wait
