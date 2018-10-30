#!/bin/bash
#
# Copyright (c) 2018 Red Hat, Inc.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
export CUR_DIR=$(cd "$(dirname "$0")"; pwd)
export CALLER=$(basename $0)

cd $CUR_DIR

printHelp() {
    local usage="
Usage: ${CALLER} [-Mmode] [options] [tests scope]

Options:
    --http                              Use 'http' protocol to connect to product (default value)
    --https                             Use 'https' protocol to connect to product
    --host=<PRODUCT_HOST>               Set host where product is deployed, default is 'codeready-codeready.<IP>.nip.io'
    --port=<PRODUCT_PORT>               Set port of the product, default is 80

Modes (defines environment to run tests):
    -Mlocal                             All tests will be run in a Web browser on the developer machine.
                                        Recommended if test visualization is needed and for debugging purpose.

       Options that go with 'local' mode:
       --web-driver-version=<VERSION>    To use the specific version of the WebDriver, be default the latest will be used: "${WEBDRIVER_VERSION}"
       --web-driver-port=<PORT>          To run WebDriver on the specific port, by default: "${WEBDRIVER_PORT}"
       --threads=<THREADS>               Number of tests that will be run simultaneously. It also means the very same number of
                                        Web browsers will be opened on the developer machine.
                                        Default value is in range [2,5] and depends on available RAM.

    -Mgrid (default)                    All tests will be run in parallel among several docker containers.
                                        One container per thread. Recommended to run test suite.

        Options that go with 'grid' mode:
        --threads=<THREADS>             Number of tests that will be run simultaneously.
                                        Default value is in range [2,5] and depends on available RAM.

Define tests scope:
    --test=<TEST_CLASS>                 Single test/package to run.
                                        For example: '--test=DialogAboutTest', '--test=org.eclipse.che.selenium.git.**'.
    --suite=<SUITE>                     Test suite to run, found:
"$(for x in $(ls -1 src/test/resources/suites); do echo "                                            * "$x; done)"
    --exclude=<TEST_GROUPS_TO_EXCLUDE>  Comma-separated list of test groups to exclude from execution.
                                        For example, use '--exclude=github' to exclude GitHub-related tests.

Handle failing tests:
    --failed-tests                      Rerun failed tests that left after the previous try
    --regression-tests                  Rerun regression tests that left after the previous try
    --rerun [ATTEMPTS]                  Automatically rerun failing tests.
                                        Default attempts number is 1.

Other options:
    --help                              Display help information
    --debug                             Run tests in debug mode
    --skip-sources-validation           Fast build. Skips source validation and enforce plugins
    --workspace-pool-size=[<SIZE>|auto] Size of test workspace pool.
                                        Default value is 0, that means that test workspaces are created on demand.

HOW TO of usage:
    Run tests from 'CodereadySuite.xml' against locally deployed CodeReady Workspaces on OpenShift Origin in grid mode using HTTP protocol:
        ${CALLER}

    Test locally deployed CodeReady Workspaces on OpenShift Origin and automatically rerun failing tests:
        ${CALLER} --rerun [ATTEMPTS]

    Run single test or package of tests:
        ${CALLER} <...> --test=<TEST>

    Run suite:
        ${CALLER} <...> --suite=<PATH_TO_SUITE>

    Rerun failed tests:
        ${CALLER} <...> --failed-tests
        ${CALLER} <...> --failed-tests --rerun [ATTEMPTS]

    Debug selenium test:
        ${CALLER} -Mlocal --test=<TEST> --debug
"

    printf "%s" "${usage}"
}

if [[ $@ =~ --help ]]; then
    printHelp
    exit
fi

TESTS_SCOPE="--suite=CodereadySuite.xml"
CLEAN_GOAL="clean"

IP=$(docker run --net=host eclipse/che-ip:nightly)
PRODUCT_HOST="codeready-codeready.${IP}.nip.io"
PRODUCT_PORT=80

for var in "$@"; do
    if [[ "$var" =~ --test=.* ]] || [[ "$var" =~ --suite=.* ]]; then
        TESTS_SCOPE=
        break
    fi

    if [[ "$var" =~ --host=.* ]]; then
        PRODUCT_HOST=$(echo "$var" | sed -e "s/--host=//g")
        break
    fi

    if [[ "$var" =~ --port=.* ]]; then
        PRODUCT_PORT=$(echo "$var" | sed -e "s/--port=//g")
        break
    fi

    if [[ "$var" == "--compare-with-ci" ]] \
        || [[ "$var" == "--failed-tests" ]] \
        || [[ "$var" == "--regression-tests" ]]; then
        TESTS_SCOPE=
        CLEAN_GOAL=
        break
    fi
done

export CHE_INFRASTRUCTURE=openshift

mvn $CLEAN_GOAL dependency:unpack-dependencies \
    -DincludeArtifactIds=che-selenium-core \
    -DincludeGroupIds=org.eclipse.che.selenium \
    -Dmdep.unpack.includes=webdriver.sh \
    -DoutputDirectory=${CUR_DIR}/target/bin
chmod +x target/bin/webdriver.sh

(target/bin/webdriver.sh "$TESTS_SCOPE" --multiuser --host=${PRODUCT_HOST} --port=${PRODUCT_PORT} $@)
