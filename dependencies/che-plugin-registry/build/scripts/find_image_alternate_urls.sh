#!/bin/bash

image="$1"
echo "$image" | sed -r \
        `# for CRW images, use internal Brew versions when not yet released to RHCC` \
        -e "s|registry.redhat.io/codeready-workspaces/|registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-|g" \
        `# for RHSCL images, try non-authenticated RHCC instead of authenticated RHIO` \
        -e "s|registry.redhat.io/rhscl/|registry.access.redhat.com/rhscl/|g" \
        `# for operator, replace internal container name with quay name` \
        -e "s|crw-2-rhel8-operator|operator-rhel8|g"
echo "$image" | sed -r \
        -e "s|registry.redhat.io/([^/]+)/|registry-proxy.engineering.redhat.com/rh-osbs/\1-|g" \
        -e "s|registry.access.redhat.com/([^/]+)/|registry-proxy.engineering.redhat.com/rh-osbs/\1-|g"
