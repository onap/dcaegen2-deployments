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
#   ONAP common Kubernetes namespace in ONAP_NAMESPACE environment variable
#   If DCAE components are deployed in a separate Kubernetes namespace, that namespace in DCAE_NAMESPACE variable.
#   Consul address with port in CONSUL variable
#   Plugin wagon files in /wagons
# 	Blueprints for components to be installed in /blueprints
#   Input files for components to be installed in /inputs
#   Configuration JSON files that need to be loaded into Consul in /dcae-configs

set -ex

# Consul service registration data
CBS_REG='{"ID": "dcae-cbs0", "Name": "config_binding_service", "Address": "config-binding-service", "Port": 10000}'
CBS_REG1='{"ID": "dcae-cbs1", "Name": "config-binding-service", "Address": "config-binding-service", "Port": 10000}'
INV_REG='{"ID": "dcae-inv0", "Name": "inventory", "Address": "inventory", "Port": 8080}'
HE_REG='{"ID": "dcae-he0", "Name": "holmes-engine-mgmt", "Address": "holmes-engine-mgmt", "Port": 9102}'
HR_REG='{"ID": "dcae-hr0", "Name": "holmes-rule-mgmt", "Address": "holmes-rule-mgmt", "Port": 9101}'

# Cloudify Manager will always be in the ONAP namespace.
CM_REG='{"ID": "dcae-cm0", "Name": "cloudify_manager", "Port": 80, "Address": "dcae-cloudify-manager.'${ONAP_NAMESPACE}'"}'
# Policy handler will be looked up from a plugin on CM.  If DCAE components are running in a different k8s
# namespace than CM (which always runs in the common ONAP namespace), then the policy handler address must
# be qualified with the DCAE namespace.
PH_REG='{"ID": "dcae-ph0", "Name": "policy_handler", "Port": 25577, "Address": "policy-handler'
if [ ! -z "${DCAE_NAMESPACE}" ]
then
	PH_REG="${PH_REG}.${DCAE_NAMESPACE}"
fi
PH_REG="${PH_REG}\"}"

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
curl -v -X PUT -H "Content-Type: application/json" --data "${PH_REG}" ${CONSUL}/v1/agent/service/register
curl -v -X PUT -H "Content-Type: application/json" --data "${HE_REG}" ${CONSUL}/v1/agent/service/register
curl -v -X PUT -H "Content-Type: application/json" --data "${HR_REG}" ${CONSUL}/v1/agent/service/register

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

set +e
# (don't let failure of one stop the script.  this is likely due to image pull taking too long)
# Deploy platform components
deploy config_binding_service k8s-config_binding_service.yaml k8s-config_binding_service-inputs.yaml
deploy inventory k8s-inventory.yaml k8s-inventory-inputs.yaml
deploy deployment_handler k8s-deployment_handler.yaml k8s-deployment_handler-inputs.yaml
deploy policy_handler k8s-policy_handler.yaml k8s-policy_handler-inputs.yaml
deploy pgaas_initdb k8s-pgaas-initdb.yaml k8s-pgaas-initdb-inputs.yaml

# Deploy service components
deploy tca k8s-tca.yaml k8s-tca-inputs.yaml
deploy ves k8s-ves.yaml k8s-ves-inputs.yaml
# holmes_rules must be deployed before holmes_engine
deploy holmes_rules k8s-holmes-rules.yaml k8s-holmes_rules-inputs.yaml
deploy holmes_engine k8s-holmes-engine.yaml k8s-holmes_engine-inputs.yaml
set -e

# Display deployments, for debugging purposes
cfy deployments list
