#!/bin/bash
# ================================================================================
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
# ================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END=========================================================

# Clean up DCAE during ONAP uninstall
#
# When helm delete is being used to uninstall all of ONAP, helm does
# not know about k8s entities that were created by Cloudify Manager.
# This script--intended to run as a preUninstall hook when Cloudify Manager itself
# is undeleted--uses Cloudify to clean up the k8s entities deployed by Cloudify.
#
# Rather than using the 'cfy uninstall' command to run a full 'uninstall' workflow
# against the deployments, this script uses 'cfy executions' to run a 'stop'
# stop operation against the nodes in each deployment.  The reason for this is that,
# at the time this script run, we have no# guarantees about what other components are
# still running.  In particular, a full 'uninstall' will cause API requests to Consul
# and will raise RecoverableErrors if it cannot connect.  RecoverableErrors send Cloudify
# into a long retry loop.  Instead, we invoke only the 'stop'
# operation on each node, and the 'stop' operation uses the k8s API (guaranteed to be
# present) but not the Consul API.
#
# Note that the script finds all of the deployments known to Cloudify and runs the
# 'stop' operation on every node
# The result of the script is that all of the k8s entities deployed by Cloudify
# should be destroyed.  Cloudify Manager itself isn't fully cleaned up (the deployments and
# blueprints are left), but that doesn't matter because Cloudify Manager will be
# destroyed by Helm.


set -x
set +e

# Get the CM admin password from the config file
# Brittle, but the container is built with an unchanging version of CM,
# so no real risk of a breaking change
CMPASS=$(grep 'admin_password:' /etc/cloudify/config.yaml | cut -d ':' -f2 | tr -d ' ')
TYPENAMES='[dcae.nodes.ContainerizedServiceComponent,dcae.nodes.ContainerizedServiceComponent,dcae.nodes.ContainerizedServiceComponent,dcae.nodes.ContainerizedServiceComponent]'

# Uninstall components managed by Cloudify
# Get the list of deployment ids known to Cloudify via curl to Cloudify API.
# The output of the curl is JSON that looks like {"items" :[{"id": "config_binding_service"}, ...], "metadata" :{...}}
#
# jq gives us the just the deployment ids (e.g., "config_binding_service"), one per line
#
# xargs -I lets us run the cfy executions command once for each deployment id extracted by jq

curl -Ss --user admin:$CMPASS -H "Tenant: default_tenant" "localhost/api/v3.1/deployments?_include=id" \
| /bin/jq .items[].id \
| xargs -I % sh -c 'cfy executions start -d %  -p type_names=${TYPENAMES} -p operation=cloudify.interfaces.lifecycle.stop execute_operation'