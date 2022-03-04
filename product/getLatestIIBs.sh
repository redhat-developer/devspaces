usage () {
	echo "
Usage: 
  $0 -t CRW_VERSION
"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-t') CRW_VERSION="$2"; shift 1;;
  esac
  shift 1
done

if [[ -z ${CRW_VERSION} ]]; then usage; exit 1; fi

echo "Checking for latest IIBs for CRW ${CRW_VERSION} ..."; echo
for csv in operator-metadata operator-bundle; do
  lastcsv=$(curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=30&contains=codeready-workspaces" | \
jq ".raw_messages[].msg.index | .added_bundle_images[0]" -r | sort -uV | grep "${csv}:${CRW_VERSION}" | tail -1 | \
sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-##");

  curl -sSLk "https://datagrepper.engineering.redhat.com/raw?topic=/topic/VirtualTopic.eng.ci.redhat-container-image.index.built&delta=1728000&rows_per_page=30&contains=codeready-workspaces" | \
jq ".raw_messages[].msg.index | [.added_bundle_images[0], .index_image, .ocp_version] | @tsv" -r | sort -uV | \
grep "${lastcsv}" | sed -r -e "s#registry-proxy.engineering.redhat.com/rh-osbs/codeready-workspaces-#  #";
  echo;
done

