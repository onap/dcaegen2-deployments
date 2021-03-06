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


if [[ "$HOSTNAME" == *redis-cluster-0 ]]; then
  {
  NODES=""
  echo "====> wait for all 6 redis pods up"
  while [ "$(echo $NODES | wc -w)" -lt 6 ]
  do
    echo "======> $(echo $NODES |wc -w) / 6 pods up"
    sleep 5
    RESP=$(wget -vO- --ca-certificate /var/run/secrets/kubernetes.io/serviceaccount/ca.crt  --header "Authorization: Bearer $(</var/run/secrets/kubernetes.io/serviceaccount/token)" https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/namespaces/default/pods?labelSelector=name=onap-dcaegen2-redis-cluster)
    NODES=$(echo $RESP | jq -r '.items[].status.podIP + ":6379"')
  done
  echo "====> all 6 redis cluster pods are up. wait 10 seconds before the next step"; echo
  sleep 10

  echo "====> Configure the cluster"

  # we might want NODES w/o quotes
  redis-trib create --replicas 1 $NODES
  } &
fi

redis-server
