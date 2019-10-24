[![Master Build Status](https://ci.centos.org/buildStatus/icon?subject=master&job=devtools-che-devfile-registry-build-master/)](https://ci.centos.org/job/devtools-che-devfile-registry-build-master/)
[![Nightly Build Status](https://ci.centos.org/buildStatus/icon?subject=nightly&job=devtools-che-devfile-registry-nightly/)](https://ci.centos.org/job/devtools-che-devfile-registry-nightly/)
[![Release Build Status](https://ci.centos.org/buildStatus/icon?subject=release&job=devtools-che-devfile-registry-release/)](https://ci.centos.org/job/devtools-che-devfile-registry-release/)
[![Preview Release Build Status](https://ci.centos.org/buildStatus/icon?subject=release-preview&job=devtools-che-devfile-registry-release-preview/)](https://ci.centos.org/job/devtools-che-devfile-registry-release-preview/)

# Eclipse Che devfile registry

This repository holds ready-to-use Devfiles for different languages and technologies.

## Build Eclipse Che devfile registry docker image

Execute
```shell
docker build --no-cache -t quay.io/eclipse/che-devfile-registry:nightly --target registry .

# or to use & create a RHEL-based image
docker build --no-cache -t quay.io/eclipse/che-devfile-registry:nightly -f build/dockerfiles/rhel.Dockerfile --target registry.
```
Where `--no-cache` is needed to prevent usage of cached layers with devfile registry files.
Useful when you change devfile files and rebuild the image.

Note that the Dockerfiles feature multi-stage build, so it requires Docker of version 17.05 and higher.
Though you may also just provide the image to the older versions of Docker (ex. on Minishift) by having it build on newer version, and pushing and pulling it from Docker Hub.

`quay.io/eclipse/che-devfile-registry:nightly` image would be rebuilt after each commit in master.

### Offline registry

The default docker build has multiple targets:
- `--target registry` is used to build the default devfile registry, where projects in devfiles refer to publically hosted git repos
- `--target offline-registry` is used to build a devfile registry which self-hosts projects as zip files.

The offline registry build will, during the docker build, pull zips from all projects hosted on github and store them in the `/resources` path. This registry should be deployed with environment variable `CHE_DEVFILE_REGISTRY_URL` set to the URL of the route/endpoint that exposes the devfile registry, as devfiles need to be rewritten to point to internally hosted zip files.

## OpenShift
You can deploy Che devfile registry on Openshift with command.
```
  oc new-app -f deploy/openshift/che-devfile-registry.yaml \
             -p IMAGE="quay.io/eclipse/che-devfile-registry" \
             -p IMAGE_TAG="nightly" \
             -p PULL_POLICY="Always"
```

## Kubernetes

You can deploy Che devfile registry on Kubernetes using [helm](https://docs.helm.sh/). For example if you want to deploy it in the namespace `kube-che` and you are using `minikube` you can use the following command.

```bash

NAMESPACE="kube-che"
DOMAIN="$(minikube ip).nip.io"
helm upgrade --install che-devfile-registry \
    --debug \
    --namespace ${NAMESPACE} \
    --set global.ingressDomain=${DOMAIN} \
    ./deploy/kubernetes/che-devfile-registry/

```

You can use the following command to uninstall it.

```bash

helm delete --purge che-devfile-registry

```

## Docker

```
docker run -it --rm -p 8080:8080 quay.io/eclipse/che-devfile-registry:nightly
```

## CI
The following [CentOS CI jobs](https://ci.centos.org/) are associated with the repository:

- [`master`](https://ci.centos.org/job/devtools-che-devfile-registry-build-master/) - builds CentOS images on each commit to the [`master`](https://github.com/eclipse/che-devfile-registry/tree/master) branch and pushes them to [quay.io](https://quay.io/organization/eclipse).
- [`nightly`](https://ci.centos.org/job/devtools-che-devfile-registry-nightly/) - builds CentOS images and pushes them to [quay.io](https://quay.io/organization/eclipse) on a daily basis from the [`master`](https://github.com/eclipse/che-devfile-registry/tree/master) branch. The `nightly` version of the devfile registry is used by default by the `nightly` version of the [Eclipse Che](https://github.com/eclipse/che), which is also built on a daily basis by the [`all-che-docker-images-nightly`](all-che-docker-images-nightly/) CI job.
- [`release`](https://ci.centos.org/job/devtools-che-devfile-registry-release/) - builds CentOS and corresponding RHEL images from the [`release`](https://github.com/eclipse/che-devfile-registry/tree/release) branch. CentOS images are public and pushed to [quay.io](https://quay.io/organization/eclipse). RHEL images are also pushed to quay.io, but to the private repositories and then used by the ["Hosted Che"](https://www.eclipse.org/che/docs/che-7/hosted-che/) devfile registry - https://che-devfile-registry.openshift.io/. 
- [`release-preview`](https://ci.centos.org/job/devtools-che-devfile-registry-release-preview/) - builds CentOS and corresponding RHEL images from the [`release-preview`](https://github.com/eclipse/che-devfile-registry/tree/release-preview) branch and automatically updates ["Hosted Che"](https://www.eclipse.org/che/docs/che-7/hosted-che/) staging devfile registry deployment based on the new version of images - https://che-devfile-registry.prod-preview.openshift.io/. CentOS images are public and pushed to [quay.io](https://quay.io/organization/eclipse). RHEL images are also pushed to quay.io, but to the private repositories.

### License
Che is open sourced under the Eclipse Public License 2.0.
