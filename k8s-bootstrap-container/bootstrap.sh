#!/bin/bash
# Install DCAE via Cloudify Manager
# Expects:
#   CM address (IP or DNS) in CMADDR environment variable
#   CM password in CMPASS environment variable (assumes user is "admin")
#   Plugin wagon files in /wagons

set -x

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

# Load plugins onto CM
for wagon in /wagons/*.wgn
do
    cfy plugins upload ${wagon}
done

# Deploy platform components
deploy config_binding_service k8s-config_binding_service.yaml k8s-config_binding_service-inputs.yaml
deploy inventory k8s-inventory.yaml k8s-inventory-inputs.yaml
deploy deployment_handler k8s-deployment_handler.yaml k8s-deployment_handler-inputs.yaml
deploy policy_handler k8s-policy_handler.yaml k8s-policy_handler-inputs.yaml

# Keep the container running
# Useful to exec into it for debugging and uninstallation
while true
do
    sleep 120
done