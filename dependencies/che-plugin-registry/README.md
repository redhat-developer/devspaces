[![CircleCI](https://circleci.com/gh/eclipse/che-plugin-registry.svg?style=svg)](https://circleci.com/gh/eclipse/che-plugin-registry)
[![Master Build Status](https://ci.centos.org/buildStatus/icon?subject=master&job=devtools-che-plugin-registry-build-master/)](https://ci.centos.org/job/devtools-che-plugin-registry-build-master/)
[![Nightly Build Status](https://ci.centos.org/buildStatus/icon?subject=nightly&job=devtools-che-plugin-registry-nightly/)](https://ci.centos.org/job/devtools-che-plugin-registry-nightly/)
[![Release Build Status](https://ci.centos.org/buildStatus/icon?subject=release&job=devtools-che-plugin-registry-release/)](https://ci.centos.org/job/devtools-che-plugin-registry-release/)
[![Release Preview Build Status](https://ci.centos.org/buildStatus/icon?subject=release-preview&job=devtools-che-plugin-registry-release-preview/)](https://ci.centos.org/job/devtools-che-plugin-registry-release-preview/)

# Eclipse Che plugin registry

This repository holds ready-to-use plugins for different languages and technologies.

## Building and publishing third party VSIX extensions for plugin registry
See: https://github.com/redhat-developer/codeready-workspaces/blob/master/devdoc/building/build-vsix-extension.adoc

## Build registry container image

This repository contains a `build.sh` script at its root that can be used to build the registry:
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
    --latest-only
        Build registry to only contain 'latest' meta.yamls; default: 'false'
    --offline
        Build offline version of registry, with all artifacts included
        cached in the registry; disabled by default.
    --rhel
        Build using the rhel.Dockerfile (UBI images) instead of default
```

Note that the Dockerfiles in this repository utilize multi-stage builds, so Docker version 17.05 or higher is required.

### Offline and airgapped registry images

Using the `--offline` option in `build.sh` will build the registry to contain all referenced extension artifacts (i.e. all `.theia` and `.vsix` archives). The offline version of the plugin registry is useful in network-limited scenarios, as it avoids the need to download plugin extensions from the outside internet.

## Deploy the registry to OpenShift

You can deploy the registry to Openshift as follows:

```bash
  oc new-app -f deploy/openshift/che-plugin-registry.yml \
             -p IMAGE="quay.io/eclipse/che-plugin-registry" \
             -p IMAGE_TAG="nightly" \
             -p PULL_POLICY="Always"
```

## Run the registry 

```bash
docker run -it  --rm  -p 8080:8080 quay.io/eclipse/che-plugin-registry:nightly
```

## Plugin meta YAML structure

Here is an overview of all fields that can be present in plugin meta YAML files. This document represents the current `v3` version.

```yaml
apiVersion:            # plugin meta.yaml API version -- v2; v1 supported for backwards compatability
publisher:             # publisher name; must match [-a-z0-9]+
name:                  # plugin name; must match [-a-z0-9]+
version:               # plugin version; must match [-.a-z0-9]+
type:                  # plugin type; e.g. "Theia plugin", "Che Editor"
displayName:           # name shown in user dashboard
title:                 # plugin title
description:           # short description of plugin's purpose
icon:                  # link to SVG or PNG icon
repository:            # URL for plugin (e.g. Github repo)
category:              # see [1]
firstPublicationDate:  # optional; see [2]
latestUpdateDate:      # optional; see [3]
deprecate:             # optional; section for deprecating plugins in favor of others
  autoMigrate:         # boolean
  migrateTo:           # new org/plugin-id/version, e.g. redhat/vscode-apache-camel/latest
spec:                  # spec (used to be che-plugin.yaml)
  endpoints:           # optional; plugin endpoints -- see https://www.eclipse.org/che/docs/che-6/servers.html for more details
    - name:
      public:            # if true, endpoint is exposed publicly
      targetPort:
      attributes:
        protocol:        # protocol used for communicating over endpoint, e.g. 'ws' or 'http'
        secure:          # use secure version of protocol above; convert 'ws' -> 'wss', 'http' -> 'https'
        discoverable:    # if false, no k8s service is created for this endpoint
        cookiesAuthEnabled: # if true, endpoint is exposed through JWTProxy
        type:
        path:
  containers:          # optional; sidecar containers for plugin
    - image:
      name:              # name used for sidecar container
      memoryLimit:       # Kubernetes/OpenShift-spec memory limit string (e.g. "512Mi"). Refer to https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#meaning-of-memory for details.
      memoryRequest:     # Kubernetes/OpenShift-spec memory request string (e.g. "256Mi"). Refer to https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#meaning-of-memory for details.
      cpuLimit:          # Kubernetes/OpenShift-spec CPU limit string (e.g. "500m"). Refer to https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#meaning-of-cpu for details.
      cpuRequest:        # Kubernetes/OpenShift-spec CPU request string (e.g. "125m"). Refer to https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#meaning-of-cpu for details.
      env:               # list of env vars to set in sidecar
        - name:
          value:
      command:           # optional; definition of root process command inside container
        - /bin/sh
      args:              # optional; list arguments for root process command inside container
        - -c
        - ./entrypoint.sh
      volumes:           # volumes required by plugin
        - mountPath:
          name:
          ephemeral: # boolean; if true volume will be ephemeral, otherwise volume will be persisted
      ports:             # ports exposed by plugin (on the container)
        - exposedPort:
      commands:          # development commands available to plugin container
        - name:
          workingDir:
          command:       # list of commands + arguments, e.g.:
            - rm
            - -rf
            - /cache/.m2/repository
      mountSources:      # boolean
      lifecycle:         # container lifecycle hooks -- see https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/
        postStart:       # the postStart event immediately after a Container is started -- see https://kubernetes.io/docs/tasks/configure-pod-container/attach-handler-lifecycle-event/
          exec:          # Executes a specific command, resources consumed by the command are counted against the Container
            command: ["/bin/sh", "-c", "/bin/post-start.sh"]  # Command is the command line to execute inside the container, the working directory for the command is root ('/') 
                                                              # in the container's filesystem. The command is simply exec'd, it is not run inside a shell, so traditional shell
                                                              # instructions ('|', etc) won't work. To use a shell, you need to explicitly call out to that shell. Exit status 
                                                              # of 0 is treated as live/healthy and non-zero is unhealthy
                                                              # -- see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.18/#execaction-v1-core
        preStop:         # the preStop event immediately before the Container is terminated -- see https://kubernetes.io/docs/tasks/configure-pod-container/attach-handler-lifecycle-event/
          exec:          # Executes a specific command, resources consumed by the command are counted against the Container
            command: ["/bin/sh","-c","/bin/pre-stop.sh"]      # Command is the command line to execute inside the container, the working directory for the command is root ('/') 
                                                              # in the container's filesystem. The command is simply exec'd, it is not run inside a shell, so traditional shell
                                                              # instructions ('|', etc) won't work. To use a shell, you need to explicitly call out to that shell. Exit status 
                                                              # of 0 is treated as live/healthy and non-zero is unhealthy
                                                              # -- see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.18/#execaction-v1-core
  initContainers:      # optional; init containers for sidecar plugin
    - image:
      name:              # name used for sidecar container
      memorylimit:       # Kubernetes/OpenShift-spec memory limit string (e.g. "512Mi")
      env:               # list of env vars to set in sidecar
        - name:
          value:
      command:           # optional; definition of root process command inside container
        - /bin/sh
      args:              # optional; list arguments for root process command inside container
        - -c
        - ./entrypoint.sh
      volumes:           # volumes required by plugin
        - mountPath:
          name:
          ephemeral: # boolean; if true volume will be ephemeral, otherwise volume will be persisted
      ports:             # ports exposed by plugin (on the container)
        - exposedPort:
      commands:          # development commands available to plugin container
        - name:
          workingDir:
          command:       # list of commands + arguments, e.g.:
            - rm
            - -rf
            - /cache/.m2/repository
      mountSources:      # boolean
  workspaceEnv:        # optional; env vars for the workspace
    - name:
      value:
  extensions:            # optional; required for VS Code/Theia plugins; list of urls to plugin artifacts (.vsix/.theia files) -- examples follow
    - https://github.com/Azure/vscode-kubernetes-tools/releases/download/0.1.17/vscode-kubernetes-tools-0.1.17.vsix # example
    - vscode:extension/redhat.vscode-xml # example
    - https://github.com/redhat-developer/omnisharp-theia-plugin/releases/download/v0.0.1/omnisharp_theia_plugin.theia # example
    - relative:extension/resources/java-0.46.0-1549.vsix # example; see [4]
```

1 - Category must be equal to one of the following: "Editor", "Debugger", "Formatter", "Language", "Linter", "Snippet", "Theme", "Other"

2 - firstPublicationDate is not required to be present in YAML, as if not present, it will be generated during Plugin Registry dockerimage build

3 - latestUpdateDate is not required to be present in YAML, as it will be generated during Plugin Registry dockerimage build

4 - extensions starting with `relative:extension` are resolved relative to the path of `index.json` -- e.g. `v3`. This is primarily to support an offline or airgapped instance of the plugin registry. See [Offline and airgapped registry images](#offline-and-airgapped-registry-images) for details.

Note that the `spec` section above comes from the older `che-plugin.yaml` spec. The `endpoints`, `containers`, and `workspaceEnv` are passed back to Che server and are used to define the sidecar that is added to the workspace.

At the moment, some of these fields (that are related to plugin viewer) are validated during the Plugin Registry dockerimage build.

## Get index list of all plugins

Example:

```bash
curl  "http://localhost:8080/v3/plugins/index.json"
```

or

```bash
curl  "http://localhost:8080/v3/plugins/"
```

Response:

```json
[
  {
    "id": "eclipse/che-theia/latest",
    "displayName": "theia-ide",
    "version": "latest",
    "type": "Che Editor",
    "name": "che-theia",
    "description": "Eclipse Theia",
    "publisher": "eclipse",
    "links": {
      "self": "/v3/plugins/eclipse/che-theia/latest"
    }
  },
  {
    "id": "eclipse/che-theia/next",
    "displayName": "theia-ide",
    "version": "next",
    "type": "Che Editor",
    "name": "che-theia",
    "description": "Eclipse Theia, get the latest release each day.",
    "publisher": "eclipse",
    "links": {
      "self": "/v3/plugins/eclipse/che-theia/next"
    }
  },
  {
    "id": "eclipse/x-lang-ls/2019.08.20",
    "displayName": "x lang support",
    "version": "2019.08.20",
    "type": "VS Code extension",
    "name": "x-lang-ls",
    "description": "Provides support for language x",
    "publisher": "eclipse",
    "deprecate": {
      "automigrate": true,
      "migrateTo": "eclipse/x-lang-ls/2019.11.05"
    },
     "links": {
      "self": "/v3/plugins/eclipse/x-lang-ls/2019.08.20"
    }
  },
  {
    "id": "eclipse/x-lang-ls/2019.11.05",
    "displayName": "x lang support",
    "version": "2019.11.05",
    "type": "VS Code extension",
    "name": "x-lang-ls",
    "description": "Provides support for language x",
    "publisher": "eclipse",
    "links": {
      "self": "/v3/plugins/eclipse/x-lang-ls/2019.11.05"
    }
  }
]
```

## Get meta.yaml of a plugin

Example:

```bash
curl  "http://localhost:8080/v3/plugins/eclipse/che-theia/next/meta.yaml"
```

or

```bash
curl  "http://localhost:8080/v3/plugins/eclipse/che-theia/latest/meta.yaml"
```

Response:

```yaml
apiVersion: v2
publisher: eclipse
name: che-theia
version: next
type: Che Editor
displayName: theia-ide
title: Eclipse Theia development version.
description: Eclipse Theia, get the latest release each day.
icon: https://raw.githubusercontent.com/theia-ide/theia/master/logo/theia-logo-no-text-black.svg?sanitize=true
category: Editor
repository: https://github.com/eclipse/che-theia
firstPublicationDate: "2019-03-07"
spec:
  endpoints:
  - name: theia
    public: true
    targetPort: 3100
    attributes:
      protocol: http
      type: ide
      secure: true
      cookiesAuthEnabled: true
      discoverable: false
  - name: theia-dev
    public: true
    targetPort: 3130
    attributes:
      protocol: http
      type: ide-dev
      discoverable: false
  - name: theia-redirect-1
    public: true
    targetPort: 13131
    attributes:
      protocol: http
      discoverable: false
  - name: theia-redirect-2
    public: true
    targetPort: 13132
    attributes:
      protocol: http
      discoverable: false
  - name: theia-redirect-3
    public: true
    targetPort: 13133
    attributes:
      protocol: http
      discoverable: false
  containers:
  - name: theia-ide
    image: eclipse/che-theia:next
    env:
    - name: THEIA_PLUGINS
      value: local-dir:///plugins
    - name: HOSTED_PLUGIN_HOSTNAME
      value: 0.0.0.0
    - name: HOSTED_PLUGIN_PORT
      value: "3130"
    volumes:
    - mountPath: /plugins
      name: plugins
    mountSources: true
    ports:
    - exposedPort: 3100
    - exposedPort: 3130
    - exposedPort: 13131
    - exposedPort: 13132
    - exposedPort: 13133
    memoryLimit: 512M
latestUpdateDate: "2019-07-05"
```

## CI
The following [CentOS CI jobs](https://ci.centos.org/) are associated with the repository:

- [`master`](https://ci.centos.org/job/devtools-che-plugin-registry-build-master/) - builds CentOS images on each commit to the [`master`](https://github.com/eclipse/che-plugin-registry/tree/master) branch and pushes them to [quay.io](https://quay.io/organization/eclipse).
- [`nightly`](https://ci.centos.org/job/devtools-che-plugin-registry-nightly/) - builds CentOS images and pushes them to [quay.io](https://quay.io/organization/eclipse) on a daily basis from the [`master`](https://github.com/eclipse/che-plugin-registry/tree/master) branch. The `nightly` version of the plugin registry is used by default by the `nightly` version of the [Eclipse Che](https://github.com/eclipse/che), which is also built on a daily basis by the [`all-che-docker-images-nightly`](all-che-docker-images-nightly/) CI job.
- [`release`](https://ci.centos.org/job/devtools-che-plugin-registry-release/) - builds CentOS and corresponding RHEL images from the [`release`](https://github.com/eclipse/che-plugin-registry/tree/release) branch. CentOS images are public and pushed to [quay.io](https://quay.io/organization/eclipse). RHEL images are also pushed to quay.io, but to the private repositories and then used by the ["Hosted Che"](https://www.eclipse.org/che/docs/che-7/hosted-che/) plugin registry - https://che-plugin-registry.openshift.io/.
- [`release-preview`](https://ci.centos.org/job/devtools-che-plugin-registry-release-preview/) - builds CentOS and corresponding RHEL images from the [`release-preview`](https://github.com/eclipse/che-plugin-registry/tree/release-preview) branch and automatically updates ["Hosted Che"](https://www.eclipse.org/che/docs/che-7/hosted-che/) staging plugin registry deployment based on the new version of images - https://che-plugin-registry.prod-preview.openshift.io/. CentOS images are public and pushed to [quay.io](https://quay.io/organization/eclipse). RHEL images are also pushed to quay.io, but to the private repositories.

### License

Che is open sourced under the Eclipse Public License 2.0.
