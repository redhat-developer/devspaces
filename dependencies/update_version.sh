#!/bin/bash
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

VERSION=$1

usage() {
    # TODO add nocommit option?
    echo "Run this script to set the newer version across the CRW repository.
    Version must be specified as parameter, e.g. ./update_version.sh 2.4"
}

updateVersion() {
    echo $VERSION > VERSION
}

updateDevfileRegistry() {
    SCRIPT_DIR="che-devfile-registry/build/scripts"
    YAML_ROOT="che-devfile-registry/devfiles"

    readarray -d '' devfiles < <($SCRIPT_DIR/list_yaml.sh "$YAML_ROOT" | tr '\n' '\0')

    CRW_VERSION=2.4

    # replace CRW plugins with current version
    sed -E -i "s|(.*image: *?.*registry.redhat.io/codeready-workspaces/.*:).+|\1$VERSION|g" ${devfiles[@]}
}

updatePluginRegistry() {
    SCRIPT_DIR="che-plugin-registry/build/scripts"
    YAML_ROOT="che-plugin-registry/v3/plugins"

    readarray -d '' plugins < <($SCRIPT_DIR/list_yaml.sh "$YAML_ROOT" | tr '\n' '\0')
    declare -a latestPlugins
    for plugin in ${plugins[@]}
    do
        #select only latest plugins
        var1=${plugin%/*}
        var2=${var1%/*}
        latestVersion=$(cat "$var2/latest.txt")
        latestPlugin="$var2/$latestVersion/meta.yaml" 
        if [ "$plugin" == "$latestPlugin" ];then
            latestPlugins+=($plugin)
        fi
    done        
    # replace CRW plugins with current version
    sed -E -i "s|(.*image: *?.*registry.redhat.io/codeready-workspaces/.*:).+|\1$VERSION\"|g" ${latestPlugins[@]}
}

commitChanges() {
    git commit -asm "Updated CRW version to $VERSION"
}

if [[ -z $VERSION ]]; then
    usage
    exit 1
fi

updateVersion
updatePluginRegistry
updateDevfileRegistry
#commitChanges
