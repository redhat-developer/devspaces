      tmpfile=$(mktemp)
      echo ${image} | sed -r \
          `# for CRW images, use internal Brew versions when not yet released to RHCC` \
          -e "s|registry.redhat.io/codeready-workspaces/|registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-|g" \
          `# for RHSCL images, use public one as an alternate to RHCC` \
          -e "s|registry.redhat.io/rhscl/|registry.access.redhat.com/rhscl/|g" \
          `# for operator, replace internal container name with quay name` \
          -e "s|crw-2-rhel8-operator|operator-rhel8|g" \
          > ${tmpfile}
      alt_image=$(cat ${tmpfile})
      rm -f ${tmpfile}
      digest="$(skopeo inspect --tls-verify=false "docker://${alt_image}" 2>"$LOG_FILE" | jq -r '.Digest')"
      if [[ ! ${digest} ]]; then
        handle_error "$alt_image + $image"
        exit 1
      else
        echo "    $digest # ${alt_image}"
      fi
