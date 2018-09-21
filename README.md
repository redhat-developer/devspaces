### What's inside?

This repository hosts Code Ready Workspaces assembly that mainly inherits Eclipse Che artifacts and repackages some of them:

Differences as compared to upstream:

* Customized Dashboard (pics, icons, titles, loaders, links)
* Samples and Stacks modules
* Product Info plugin (IDE customizations: pics, titles links)
* Custom Dockerfile based on official RH OpenJDK image from RHCC


### How to Build

#### Pre-reqs

JDK 1.8+
Maven 3.5+

#### Build Assembly

Run the following command in the root of a repository:

```
mvn clean install
```
Be patient: since the build includes GWT compilation is may take ~3-4 mins.

Build artifact (the one used in the Docker image) will show up in `assembly/assembly-main/target/codeready-${version}/codeready-${version`


### How to Build Docker Image

Run the following command in the root of a repository:

```
docker build -t ${REGISTRY}/${REPO} .
```

You can then reference this image in your deployment (set umage pull policy to IfNotPresent to avoid pushing the image to a registry).

Please note, that stacks reference non existing images like `docker-registry.default.svc:5000/openshift/rhel-base-jdk8`. These images are built as a post installation step.