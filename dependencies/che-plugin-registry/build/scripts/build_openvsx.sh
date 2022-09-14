#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
set -e
set -o pipefail

cd /tmp
# temporary location
git clone https://github.com/che-incubator/che-openvsx.git
cd che-openvsx/server
git checkout che-openvsx

./gradlew --no-daemon assemble

mkdir -p /tmp/openvsx-lib
cp /tmp/che-openvsx/server/scripts/run-server.sh /tmp/openvsx-lib
cp /tmp/che-openvsx/server/build/libs/openvsx-server.jar /tmp/openvsx-lib && rm -rf /tmp/che-openvsx
cd /tmp/openvsx-lib
jar -xf openvsx-server.jar && rm openvsx-server.jar
