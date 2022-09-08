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
git clone https://github.com/benoitf/openvsx.git
cd openvsx/server
git checkout OPENVSX-498

./gradlew --no-daemon assemble

mkdir -p /tmp/openvsx-lib
cp /tmp/openvsx/server/scripts/run-server.sh /tmp/openvsx-lib
cp /tmp/openvsx/server/build/libs/openvsx-server.jar /tmp/openvsx-lib && rm -rf /tmp/openvsx
cd /tmp/openvsx-lib
jar -xf openvsx-server.jar && rm openvsx-server.jar
