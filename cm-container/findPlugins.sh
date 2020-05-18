#!/bin/bash
# ============LICENSE_START=======================================================
# Copyright (c)2020 AT&T Intellectual Property. All rights reserved.
# ================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END=========================================================

# Use the Nexus API to get a list of all the plugins/typefiles currently in Nexus
# under a specified root directory, passed as the first argument to the script
# We assume the repo structure that the build process uses:
# PLUGIN_ROOT/<plugin_name>/<version>/<wagon_name>.wgn
# PLUGIN_ROOT/<plugin_name>/<version>/<type_file_name>.yaml

# This code could be used as the basis for an alternative to the existing
# 'get-plugins.sh' script.  Instead of pulling a hard-coded list of plugins and
# type files from Nexus, it would pull all of the plugins and type files, in all
# available versions, from the Nexus repo.

# At the very least, it is a useful tool for finding out what plugins and
# type files have been loaded into the Nexus repo and are therefore available
# to be included in the hard-coded list.

shopt -s expand_aliases

alias cu='curl -Ss -H "Accept: application/json" -L -f'
PLUGIN_ROOT=${1:-"https://nexus.onap.org/service/local/repositories/raw/content/org.onap.dcaegen2.platform.plugins/R7/"}

function getPlugins() {
    local root=$1
    # Get URLs for all of the plugins under the plugin root directory
    local PLUGINS=$(cu $root | jq .data[].resourceURI | sed -e 's/"//g')

    # Go into each plugin directory
    for p in $PLUGINS
    do
        # Get the available versions of the plugin
        local VERSIONS=$(cu $p | jq .data[].resourceURI | sed -e 's/"//g')

        # Get wagon and type file for each version
        for v in $VERSIONS
        do
            local RESOURCES=$(cu $v | jq .data[].relativePath)
            # RESOURCES will have a list of everything in the version directory, including many timestamped
	          # wagons and type files, and some zip files as well.  For each version, there should be a single
            # non-time-stamped .wgn and a single non-timestamped .yaml file.   We try to pull these from the
            # from the list using grep, and then we reformat the results to remove quote marks and to remove
            # the first two levels of the relative path.
            # Just in case we're wrong about how many non-timestamped .wgn and .yaml files are in each directory,
            # we treat the result of the grep as an array and we take the first element only.
	          local w=($((for r in $RESOURCES; do echo $r; done) | grep ".wgn\"" | tr -d '"' | sed -e 's#^/[^/]*/[^/]*##'))
	          local t=($((for r in $RESOURCES; do echo $r; done) | grep ".yaml\"" | tr -d '"' | sed -e 's#^/[^/]*/[^/]*##'))
            echo "${w[0]}|${t[0]}"
            # We could potentially fetch the plugin wagon file and the type file here.  Probably wouldn't need
            # to have this code as a function in that case.  Also, probably should the .resourceURI (the full URL
            # of each file) rather than .relativePath, and not strip off any part of the path (the 'sed' operation
            # would not be needed.)
        done
    done
}

for p in $(getPlugins $PLUGIN_ROOT | sort)
do
  echo $p
done
