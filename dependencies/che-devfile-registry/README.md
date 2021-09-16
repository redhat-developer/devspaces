# CodeReady Workspaces devfile registry

This repository holds ready-to-use Devfiles for different languages and technologies.

## Build registry container image

This repository contains a `build.sh` script at its root that can be used to build the registry:
```
Usage: ./build.sh [OPTIONS]
Options:
    --help
        Print this message.
    --tag, -t [TAG]
        Docker image tag to be used for image; default: 'next'
    --registry, -r [REGISTRY]
        Docker registry to be used for image; default 'quay.io'
    --organization, -o [ORGANIZATION]
        Docker image organization to be used for image; default: 'crw'
    --offline
        Build offline version of registry, with all artifacts included
        cached in the registry; disabled by default.
```
By default, the built registry will be tagged `quay.io/crw/devfileregistry-rhel8:next`, and will be built with offline mode disabled.

This script listens to the `BUILDER` variable, and will use the tool specified there to build the image. For example:
```sh
BUILDER=buildah ./build.sh
```

will force the build to use `buildah`. If `BUILDER` is not specified, the script will try to use `podman` by default. If `podman` is not installed, then `buildah` will be chosen. If neither `podman` nor `buildah` are installed, the script will finally try to build with `docker`.

Note that the Dockerfiles in this repository utilize multi-stage builds, so Docker version 17.05 or higher is required.


### Build in Brew

The Jenkinsfile in this repo has moved. See:

* https://gitlab.cee.redhat.com/codeready-workspaces/crw-jenkins/-/tree/master/jobs/CRW_CI
* https://github.com/redhat-developer/codeready-workspaces-images#jenkins-jobs


### Offline and airgapped registry images

Using the `--offline` option in `build.sh` will build the registry to contain `zip` files for all projects referenced, which is useful for running Che in clusters that may not have access to GitHub. When building the offline registry, the docker build will

1. Clone all git projects referenced in devfiles, and
2. `git archive` them in the `/resources` path, making them available to workspaces.

When deploying this offline registry, it is necessary to set the environment variable `CHE_DEVFILE_REGISTRY_URL` to the URL of the route/endpoint that exposes the devfile registry, as devfiles need to be rewritten to point to internally hosted zip files.

## Deploy the registry to OpenShift

You can deploy the registry to Openshift as follows:

```bash
  oc new-app -f deploy/openshift/che-devfile-registry.yaml \
             -p IMAGE="quay.io/crw/devfileregistry-rhel8" \
             -p IMAGE_TAG="next" \
             -p PULL_POLICY="Always"
```

## Run the registry

```bash
docker run -it --rm -p 8080:8080 quay.io/crw/devfileregistry-rhel8:next
```

### License

CodeReady Workspaces is open sourced under the Eclipse Public License 2.0.
