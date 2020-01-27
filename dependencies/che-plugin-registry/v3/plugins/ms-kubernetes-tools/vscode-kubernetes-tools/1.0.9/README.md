# Eclipse Che Kubernetes Tooling Plugin

## Setting up the access to a cluster

The Plugin relies on `kubectl` to communicate with a Kubernetes cluster. So, the access to a cluster should be set in a `kubeconfig` in plugin sidecar.

`chectl` provides the [command](https://github.com/che-incubator/chectl#chectl-workspaceinject) that simplifies injecting local `kubeconfig` into a Che Workspace. When your Workspace is running, call the following command:
```shell
chectl workspace:inject -k
```
Then refresh the `Clusters` view.

## Switching container image build tool

The plugin provides [Buildah](https://github.com/containers/buildah) to enable building the images within your workspace. It's used by `Kubernetes: Run` and `Kubernetes: Debug` commands.
To switch the plugin from the default build tool (Docker) to Buildah put the following setting to user preferences (`File - Settings - Open Preferences`):
```
"vs-kubernetes": {
    "imageBuildTool": "Buildah"
}
```
