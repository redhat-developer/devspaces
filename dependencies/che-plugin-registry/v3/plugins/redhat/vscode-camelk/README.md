# Eclipse Che Tooling Plugin for Apache Camel K

## Setting up the access to a cluster from a Che Workspace

The Plugin relies on `kubectl` to communicate with a Kubernetes cluster. The access to a cluster should be set up through a `kubeconfig`.

`chectl` provides the [command](https://github.com/che-incubator/chectl#chectl-workspaceinject) that simplifies injecting local `kubeconfig` into a Che Workspace. When your Workspace is running, call the following command:
```shell
chectl workspace:inject -k
```
Then reload a browsers page to refresh the `Clusters` tree.

## Setting up Camel K instance

In case, the Kubernetes cluster on which the connection was setup doesn't contain Camel K. You can install it by opening a terminal and call `kamel install`.
