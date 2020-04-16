      tmpfile=$(mktemp)
      echo ${image} | sed -r \
          `# for CRW images, use internal Brew versions when not yet released to RHCC` \
          -e "s|registry.redhat.io/codeready-workspaces/|registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-|g" \
          `# for RHSCL images, try non-authenticated RHCC instead of authenticated RHIO` \
          -e "s|registry.redhat.io/rhscl/|registry.access.redhat.com/rhscl/|g" \
          `# for operator, replace internal container name with quay name` \
          -e "s|crw-2-rhel8-operator|operator-rhel8|g" \
          > ${tmpfile}
      alt_image=$(cat ${tmpfile})
      rm -f ${tmpfile}
      digest="$(sleep 2s; skopeo inspect --tls-verify=false "docker://${alt_image}" 2>"$LOG_FILE" | jq -r '.Digest')"
      if [[ ! ${digest} ]]; then
        # if couldn't find in public RHCC or RHIO, try internal image in registry-proxy.engineering.redhat.com/rh-osbs/
        echo ${image} | sed -r \
                  -e "s|registry.redhat.io/([^/]+)/|registry-proxy.engineering.redhat.com/rh-osbs/\1-|g" \
                  -e "s|registry.access.redhat.com/([^/]+)/|registry-proxy.engineering.redhat.com/rh-osbs/\1-|g" \
                  > ${tmpfile}
        alt_image2=$(cat ${tmpfile})
        rm -f ${tmpfile}
        digest="$(sleep 2s; skopeo inspect --tls-verify=false "docker://${alt_image2}" 2>"$LOG_FILE" | jq -r '.Digest')"
        if [[ ! ${digest} ]]; then
          # could not find digest, so fail
          handle_error "$alt_image2 + $alt_image + $image"
          exit 1
        else
          echo "    $digest # ${alt_image2}"
        fi
      else
        echo "    $digest # ${alt_image}"
      fi
