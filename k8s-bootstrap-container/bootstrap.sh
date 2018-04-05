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

# Install DCAE via Cloudify Manager
# Expects:
#   CM address (IP or DNS) in CMADDR environment variable
#   CM password in CMPASS environment variable (assumes user is "admin")
#   Consul address with port in CONSUL variable
#   Plugin wagon files in /wagons
# 	Blueprints for components to be installed in /blueprints
#   Input files for components to be installed in /inputs
#   Configuration JSON files that need to be loaded into Consul in /dcae-configs

set -ex

# Consul service registration data
CBS_REG='{"ID": "dcae-cbs0", "Name": "config_binding_service", "Address": "config-binding-service", "Port": 10000}'
CBS_REG1='{"ID": "dcae-cbs1", "Name": "config-binding-service", "Address": "config-binding-service", "Port": 10000}'
CM_REG='{"ID": "dcae-cm0", "Name": "cloudify_manager", "Address": "cloudify-manager.onap", "Port": 80}'
INV_REG='{"ID": "dcae-inv0", "Name": "inventory", "Address": "inventory", "Port": 8080}'





# Deploy components
# $1 -- name (for bp and deployment)
# $2 -- blueprint name
# $3 -- inputs file name
function deploy {
    cfy install -b $1 -d $1 -i /inputs/$3 /blueprints/$2
}
# Set up profile to access Cloudify Manager
cfy profiles use -u admin -t default_tenant -p "${CMPASS}"  "${CMADDR}"

# Output status, for debugging purposes
cfy status

# Load configurations into Consul
for config in /dcae-configs/*.json
do
    # The basename of the file is the Consul key
    key=$(basename ${config} .json)
    # Strip out comments, empty lines
    egrep -v "^#|^$" ${config} > /tmp/dcae-upload
    curl -v -X PUT -H "Content-Type: application/json" --data-binary @/tmp/dcae-upload ${CONSUL}/v1/kv/${key}
done

# For backward compatibility, load some platform services into Consul service registry
# Some components still rely on looking up a service in Consul
curl -v -X PUT -H "Content-Type: application/json" --data "${CBS_REG}" ${CONSUL}/v1/agent/service/register
curl -v -X PUT -H "Content-Type: application/json" --data "${CBS_REG1}" ${CONSUL}/v1/agent/service/register
curl -v -X PUT -H "Content-Type: application/json" --data "${CM_REG}" ${CONSUL}/v1/agent/service/register
curl -v -X PUT -H "Content-Type: application/json" --data "${INV_REG}" ${CONSUL}/v1/agent/service/register

# Store the CM password into a Cloudify secret
cfy secret create -s ${CMPASS} cmpass

# Load plugins onto CM
# Allow "already loaded" error
# (If there are other problems, will
# be caught in deployments.)
set +e
for wagon in /wagons/*.wgn
do
    cfy plugins upload ${wagon}
done
set -e

# Deploy platform components
deploy config_binding_service k8s-config_binding_service.yaml k8s-config_binding_service-inputs.yaml
deploy inventory k8s-inventory.yaml k8s-inventory-inputs.yaml
deploy deployment_handler k8s-deployment_handler.yaml k8s-deployment_handler-inputs.yaml
deploy policy_handler k8s-policy_handler.yaml k8s-policy_handler-inputs.yaml

# Display deployments, for debugging purposes
cfy deployments list
