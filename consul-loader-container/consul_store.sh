#!/bin/bash
# ================================================================================
# Copyright (c) 2019 AT&T Intellectual Property. All rights reserved.
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

# Push service registrations and key-value pairs to consul
#
# Environment variables control the consul address used:
#   -- CONSUL_PROTO:  The protocol (http or https) used to access consul.  DEFAULT: http
#   -- CONSUL_HOST: The Consul host address.  DEFAULT: consul
#   -- CONSUL_PORT: The Consul API port.  DEFAULT: 8500
#
# Command line options
# --service name|address|port :  Register a service with name 'name', address 'address', and port 'port'.
# --key keyname|filepath:  Register a key-value pair with key 'keyname' and the contents of a file at 'filepath' as its value
# --key-yaml keyname|filepath: Register a key-value pair with name 'keyname', converting the YAML content of the file at 'filepath'
#   to JSON, and storing the JSON result as the value.  This is used for Helm deployment of DCAE microservices, where the initial
#   application configuration is stored in a Helm values.yaml file in YAML form.  --key-yaml converts the YAML configuration into
#   JSON, which is the format that microservices expect.
# -- delete-key
# A command can include multiple instances of each option.

CONSUL_ADDR=${CONSUL_PROTO:-http}://${CONSUL_HOST:-consul}:${CONSUL_PORT:-8500}
KV_URL=${CONSUL_ADDR}/v1/kv
REG_URL=${CONSUL_ADDR}/v1/catalog/register

# Register a service into Consul so that it can be discovered via the Consul service discovery API
#  $1: Name under which service is registered
#  $2: Address (typically DNS name, but can be IP) of the service
#  $3: Port used by the service
function register_service {
  service="{\"Node\": \"dcae\", \"Address\": \"$2\", \"Service\": {\"Service\": \"$1\", \"Address\": \"$2\", \"Port\": $3}}"
  echo $service
  curl -v -X PUT --data-binary "${service}" -H 'Content-Type: application/json' $REG_URL
}

# Store the contents of a file into Consul KV store
#  $1: Key under which content is stored
#  $2: Path to file whose content will be the value associated with the key
function put_key {
  curl -v -X PUT --data-binary @$2 -H 'Content-Type: application/json' ${KV_URL}/$1
}

# Delete a key from the Consul KV store
# $1: Key to be deleted
function delete_key {
  curl -v -X DELETE ${KV_URL}/$1
}

set -x

# Check Consul readiness
# The readiness container waits for a "consul-server" container to be ready,
# but this isn't always enough.  We need the Consul API to be up and for
# the cluster to be formed, otherwise our Consul accesses might fail.
# Wait for Consul API to come up
until curl ${CONSUL_ADDR}/v1/agent/services
do
    echo Waiting for Consul API
    sleep 60
done
# Wait for a leader to be elected
until [[ "$(curl -Ss {$CONSUL_ADDR}/v1/status/leader)" != '""' ]]
do
    echo Waiting for leader
    sleep 30
done

while (( "$#" ))
do
  case $1 in

  "--service")
     # ${2//|/ } turns all of the | characters in argument 2 into spaces
     # () uses the space delimited string to initialize an array
     # this turns an argument like inventory-api|inventory.onap|8080 into
     # a three-element array with elements "inventory-api", "inventory.onap", and "8080"
     s=(${2//|/ })
     register_service ${s[@]}
     shift 2;
     ;;
  "--key")
    # See above for explanation of (${2//|/ })
    kv=(${2//|/ })
    put_key ${kv[@]}
    shift 2;
    ;;
  "--key-yaml")
    # See above for explanation of (${2//|/ })
    kv=(${2//|/ })
    cat ${kv[1]} | /opt/app/yaml2json.py | put_key ${kv[0]} -
    shift 2;
    ;;
  "--delete-key")
    delete_key $2
    shift 2;
    ;;
  *)
    echo "ignoring $1"
    shift
    ;;
  esac
done
