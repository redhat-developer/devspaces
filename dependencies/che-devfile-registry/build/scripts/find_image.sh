#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
SCRIPT_DIR=$(cd "$(dirname "$0")" || exit; pwd)
[[ -z "$2" ]] && ARCH=$(uname -m) || ARCH="$2"
[[ $ARCH == "x86_64" ]] && ARCH="amd64"
# shellcheck disable=SC2064
LOG_FILE="$(mktemp)" && trap "rm $LOG_FILE" EXIT
image_urls[0]="$1"

# for other build methods or for falling back to other registries when not found, can apply transforms here
if [[ -x "${SCRIPT_DIR}/find_image_alternate_urls.sh" ]]; then
  # shellcheck disable=SC2086
  readarray -t -O 1 image_urls < <("$SCRIPT_DIR"/find_image_alternate_urls.sh ${image_urls[0]} | sort | uniq)
fi

for url in "${image_urls[@]}" ; do
  echo "Registry ${url}:" >> "$LOG_FILE"
  manifest="$(skopeo --override-arch "$ARCH" inspect --tls-verify=false "docker://${url}" 2>> "$LOG_FILE")"
  if [[ -n "$manifest" ]] ; then
    echo "$manifest"
    cat "$LOG_FILE" >&2
    exit 0
  fi
done

# not found print error
cat "$LOG_FILE" >&2
