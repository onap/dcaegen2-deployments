#!/bin/bash
# ============LICENSE_START=======================================================
# Copyright (c) 2019-2020 AT&T Intellectual Property. All rights reserved.
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
# Runs at deployment time to load the plugins/type files
# that were stored into the container file system at build time

PLUGINS_LOADED=/opt/manager/plugins-loaded
PLUGIN_DIR=/opt/plugins

# Set defaults for CM address, protocol, and port
CMADDR=${CMADDR:-dcae-cloudify-manager}
CMPROTO=${CMPROTO:-https}
CMPORT=${CMPORT:-443}

# Expect Cloudify password to be in file mounted from Kubernetes secret,
# but allow overriding by CMPASS environment variable,
# and if not provided, use the default
CMPASS=${CMPASS:-$(cat /opt/onap/cm-secrets/password 2>/dev/null)}
CMPASS=${CMPASS:-admin}

# Set up additional parameters for using HTTPS
CACERT="/opt/onap/certs/cacert.pem"
CURLTLS=""
if [ $CMPROTO = "https" ]
then
    CURLTLS="--cacert $CACERT"
fi

### FUNCTION DEFINITIONS ###

# cm_hasany: Query Cloudify Manager and return 0 (true) if there are any entities matching the query
# Used to see if something is already present on CM
# $1 -- query fragment, for instance "plugins?archive_name=xyz.wgn" to get
#  the number of plugins that came from the archive file "xyz.wgn"
function cm_hasany {
    # We use _include=id to limit the amount of data the CM sends back
    # We rely on the "metadata.pagination.total" field in the response
    # for the total number of matching entities
    COUNT=$(curl -Ss -H "Tenant: default_tenant" --user admin:${CMPASS} ${CURLTLS} "${CMPROTO}://${CMADDR}:${CMPORT}/api/v3.1/$1&_include=id" \
             | /bin/jq .metadata.pagination.total)
    if (( $COUNT > 0 ))
    then
        return 0
    else
        return 1
    fi
}

# Install plugin if it's not already installed
# $1 -- path to wagon file for plugin
# $2 -- path to type file for plugin
function install_plugin {
    ARCHIVE=$(basename $1)
    # See if it's already installed
    if cm_hasany "plugins?archive_name=$ARCHIVE"
    then
        echo plugin $1 already installed on ${CMADDR}
    else
        cfy plugin upload  -y $2 $1
    fi
}

### END FUNCTION DEFINTIONS ###

set -ex


# Wait for Cloudify Manager to come up
while ! /scripts/cloudify-ready.sh
do
    echo "Waiting for CM to come up"
    sleep 15
done

if [[ ! -f ${PLUGINS_LOADED} ]]
then

  # Each subdirectory of ${PLUGIN_DIR} contains a wagon (.wgn) and type file (.yaml)
  for p in ${PLUGIN_DIR}/*
  do
    # Expecting exactly 1 .wgn and 1 .yaml
    # But just in case, taking only the first of each
    # (If either is missing, will fail on install_plugin)
    wagons=($p/*.wgn)
    types=($p/*.yaml)
    install_plugin ${wagons[0]} ${types[0]}
  done

  # The cfy plugin upload commands issued above will return
  # before all of the processing is complete.  The processing
  # occurs in what Cloudify calls "system workflows", and if a
  # system workflow is pending or running, other operations such
  # as uploading a blueprint will fail.  So we wait for any
  # system workflows to finish before we create the PLUGINS_LOADED
  # file and exit the script.   That way, the bootstrap container
  # (which waits for k8s to declare the CM container to be ready)
  # will not try to upload blueprints while a system execution is
  # underway.  (See Jira DCAEGEN2-2430.)
  while cm_hasany "executions?is_system_workflow=true&status=pending&status=started&status=queued&status=scheduled"
  do
    echo "Waiting for running system workflows to complete"
    sleep 15
  done

  touch ${PLUGINS_LOADED}
else
  echo "Plugins already loaded"
fi
