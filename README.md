### What's inside?

This repository hosts CodeReady Workspaces assembly that mainly inherits Eclipse Che artifacts and repackages some of them:

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
NOTE: since the build includes GWT compilation it may take more than 3 minutes to complete.

Build artifact used in the Docker image will be in `assembly/assembly-main/target/codeready-${version}/codeready-${version}`


### How to Build Docker Image

Run the following command in the root of a repository:

```
docker build -t ${REGISTRY}/${REPO} .
```

You can then reference this image in your deployment (set umage pull policy to IfNotPresent to avoid pushing the image to a registry).

Please note, that stacks reference non existing images like `docker-registry.default.svc:5000/openshift/rhel-base-jdk8`. These images are built as a post installation step.

### How to Build Using NCL, Brew and OSBS

See this document for more on how to use those build systems:

* http://pkgs.devel.redhat.com/cgit/apbs/codeready-workspaces/tree/README.adoc?h=codeready-1.0-rhel-7
