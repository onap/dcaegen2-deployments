#!/bin/bash
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

CBS_REG='{"ID": "dcae-cbs0", "Name": "config_binding_service", "Address": "config-binding-service", "Port": 10000}'
# Deploy components
# $1 -- name (for bp and deployment)
# $2 -- blueprint name
# $3 -- inputs file name
function deploy {
    cfy install -b $1 -d $1 -i /inputs/$3 /blueprints/$2
}
# Set up profile to access CMs
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

# For backward compatibility, load config_binding_service into Consul as service
curl -v -X PUT -H "Content-Type: application/json" --data "${CBS_REG}" ${CONSUL}/v1/agent/service/register

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
