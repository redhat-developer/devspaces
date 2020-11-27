# Eclipse Che OpenShift Connector Plugin

## Setting up the access to a cluster

If you want to login to the same OpenShift cluster where Eclipse Che is running, execute the following command in the plugin sidecar:
```shell
oc login https://<cluster_ip>:<cluster_port> --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```
