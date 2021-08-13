#!/bin/bash
# ================================================================================
# Copyright (c) 2021 J. F. Lucas. All rights reserved.
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

# Delete a single key-value pair from the Consul KV store, with no error checking.
# (To have full error checking, using the --delete-key option on the consul_store.sh
# script.)
# This script is intended for use with a Kubernetes Job that deletes the Consul KV pair
# holding the application configuration data for a DCAE microservice, when the microservice
# is undeployed via Helm.  The reason for ignoring errors is that sometimes when a full
# ONAP deployment is being undeployed, Consul becomes unavailable before a microservice
# is deleted.  If we do a Consul delete with error checking using the consul.sh script,
# the Kubernetes Job loops indefinitely waiting for Consul to become available.  This
# script simply sends a delete key request to Consul and ignores the result.
#
# Note that failing to delete the application configuration from Consul is
# not harmful.  If a DCAE microservice is undeployed then deployed again, the
# configuration information for the new instance will overwrite the old configuration.
#
# Environment variables control the Consul address used:
#   -- CONSUL_PROTO:  The protocol (http or https) used to access consul.  DEFAULT: http
#   -- CONSUL_HOST: The Consul host address.  DEFAULT: consul
#   -- CONSUL_PORT: The Consul API port.  DEFAULT: 8500
#
# The command accepts a single argument, the name of the key to be deleted.
#
set -x
CONSUL_ADDR=${CONSUL_PROTO:-http}://${CONSUL_HOST:-consul}:${CONSUL_PORT:-8500}
KV_URL=${CONSUL_ADDR}/v1/kv

if [ "$#" -lt 1 ]
then
  echo "Command requires at least one argument"
  exit 0 # deliberately masking the error
fi
curl -v -X DELETE "${KV_URL}/$1"
exit 0 # mask any error
