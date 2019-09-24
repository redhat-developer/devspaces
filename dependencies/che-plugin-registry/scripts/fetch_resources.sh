#!/bin/bash
#
# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# pull all external references to icons, vsix files

set -e

# Generic path to where vsix and svg files will be found in the running plugin registry container image
# NOTE: Actual URL will be replaced at runtime via replace_0.0.0.0.sh script, called by entrypoint.sh
PLUGIN_REGISTRY_URL="relative:extension/resources"

# optionally, pull different file extensions
if [[ $2 ]]; then EXTS=$2; else EXTS="svg|vsix|theia"; fi

# search in a plugin folder, eg., $1 = v3/
echo "Fetch resources (${EXTS}) ... "
metayamls="$(find "$1" -name "meta.yaml" | uniq | sort | tr "\n\r\"" " ")"
c=0; for metayaml in ${metayamls}; do let c=c+1; done
i=0; for metayaml in ${metayamls}; do
  let i=i+1
  echo "[$i/$c] Fetch from '${metayaml%/meta.yaml}'"

  # get sources into local repo
  for remoterepo in $(cat $metayaml | egrep "repository:"| sed -e "s#repository: ##" | tr -d "\n\r\""); do
    remotefilepath=${remoterepo#*//}; # trim off protocol
    remotefilepath=${remotefilepath%\?*}; # trim off querystring
    remotefiledir=${remotefilepath%/*}; # get the dir into which the file will be downloaded
    remotefilepath=${remotefilepath##*/}; # trim up to last segment
    remotefilepath=${remotefilepath//.git/}; # trim off .git

    # TODO - look for a zip of the sources for matching release
    # or pull from tag
    # or pull from master

    echo "Get ${remoterepo} to sources/${remotefiledir} / ${remotefilepath}"
    mkdir -p sources/${remotefiledir}
    if [[ ! -d sources/${remotefiledir}/${remotefilepath} ]]; then 
      let i=i+1
      let c=c+1
      pushd sources/${remotefiledir} >/dev/null && git clone -q ${remoterepo} && popd >/dev/null 
    else
      pushd sources/${remotefiledir} >/dev/null && git fetch -q && popd >/dev/null 
    fi
    echo ""
	  # get binary files into local repo
	  for remotefile in $(cat $metayaml | egrep "https://|http://" | egrep -v "relative:extension/resources" | egrep "\.(${EXTS})" | sed -e "s#\(icon: \|  - \)# #g" | tr -d "\n\r\""); do
	    remotefilepath=${remotefile#*//}; # trim off protocol
	    remotefilepath=${remotefilepath%\?*}; # trim off querystring
	    remotefiledir=${remotefilepath%/*}; # get the dir into which the file will be downloaded
	    # echo "
	    # Get ${remotefile} to
	    # resources/${remotefiledir} as
	    # resources/${remotefilepath}"
	    mkdir -p resources/${remotefiledir}
	    if [[ ! -f resources/${remotefilepath} ]]; then 
	      let i=i+1
	      let c=c+1
	      echo "  [$i/$c] curl ${remotefile} -> resources/${remotefilepath}"
	      curl -sSL "${remotefile}" --output resources/${remotefilepath}
	    fi
	    # update metayaml file
	    sed -e "s#${remotefile}#${PLUGIN_REGISTRY_URL}/${remotefilepath}#g" -i $metayaml 
	    # echo ""
	  done
	done
done

