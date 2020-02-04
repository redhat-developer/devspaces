[![Master Build Status](https://ci.centos.org/buildStatus/icon?subject=master&job=devtools-che-devfile-registry-build-master/)](https://ci.centos.org/job/devtools-che-devfile-registry-build-master/)
[![Nightly Build Status](https://ci.centos.org/buildStatus/icon?subject=nightly&job=devtools-che-devfile-registry-nightly/)](https://ci.centos.org/job/devtools-che-devfile-registry-nightly/)
[![Release Build Status](https://ci.centos.org/buildStatus/icon?subject=release&job=devtools-che-devfile-registry-release/)](https://ci.centos.org/job/devtools-che-devfile-registry-release/)
[![Preview Release Build Status](https://ci.centos.org/buildStatus/icon?subject=release-preview&job=devtools-che-devfile-registry-release-preview/)](https://ci.centos.org/job/devtools-che-devfile-registry-release-preview/)

# Eclipse Che devfile registry

This repository holds ready-to-use Devfiles for different languages and technologies.

## Build Eclipse Che devfile registry docker image

This repository contains a `build.sh` script at its root that can be used to build the devfile registry:
```
Usage: ./build.sh [OPTIONS]
Options:
    --help
        Print this message.
    --tag, -t [TAG]
        Docker image tag to be used for image; default: 'nightly'
    --registry, -r [REGISTRY]
        Docker registry to be used for image; default 'quay.io'
    --organization, -o [ORGANIZATION]
        Docker image organization to be used for image; default: 'eclipse'
    --offline
        Build offline version of registry, with all sample projects
        cached in the registry; disabled by default.
    --rhel
        Build registry using UBI images instead of default
```
By default, the built registry will be tagged `quay.io/eclipse/che-devfile-registry:nightly`, and will be built with offline mode disabled.

Note that the Dockerfiles utilize multi-stage builds, so Docker version 17.05 or higher is required.

### Offline registry

Using the `--offline` option in `build.sh` will build the registry to contain `zip` files for all projects referenced, which is useful for running Che in clusters that may not have access to GitHub. When building the offline registry, the docker build will
1. Clone all git projects referenced in devfiles, and
2. `git archive` them in the `/resources` path, making them available to workspaces.

When deploying this offline registry, it is necessary to set the environment variable `CHE_DEVFILE_REGISTRY_URL` to the URL of the route/endpoint that exposes the devfile registry, as devfiles need to be rewritten to point to internally hosted zip files.

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
