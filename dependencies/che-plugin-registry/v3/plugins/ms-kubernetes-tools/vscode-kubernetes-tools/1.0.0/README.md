# Eclipse Che Kubernetes Tooling Plugin

## Setting up the access to a cluster from a Che Workspace

The Plugin relies on `kubectl` to communicate with a Kubernetes cluster. The access to a cluster should be set up through a `kubeconfig`.

`chectl` provides the [command](https://github.com/che-incubator/chectl#chectl-workspaceinject) that simplifies injecting local `kubeconfig` into a Che Workspace. When your Workspace is running, call the following command:
```shell
chectl workspace:inject -k
```
Then reload a browsers page to refresh the `Clusters` tree.
