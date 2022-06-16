#!/bin/bash

image="$1"
echo "$image" | sed -r \
        `# for DS images, use internal Brew versions when not yet released to RHCC` \
        -e "s|registry.redhat.io/devspaces/|registry-proxy.engineering.redhat.com/rh-osbs/devspaces-|g" \
        `# for RHSCL images, try non-authenticated RHCC instead of authenticated RHIO` \
        -e "s|registry.redhat.io/rhscl/|registry.access.redhat.com/rhscl/|g"
echo "$image" | sed -r \
        -e "s|registry.redhat.io/([^/]+)/|registry-proxy.engineering.redhat.com/rh-osbs/\1-|g" \
        -e "s|registry.access.redhat.com/([^/]+)/|registry-proxy.engineering.redhat.com/rh-osbs/\1-|g"
