#!/bin/bash

#############################################################################
#
# Copyright (c) 2018 AT&T Intellectual Property. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#############################################################################


cd /opt/app/config

echo "Stop and remove cloudify-manager registrator dcae-health"
docker stop cloudify-manager registrator dcae-health
docker rm cloudify-manager registrator dcae-health

echo "Stand down R2PLUS service components"
/opt/docker/docker-compose -f ./docker-compose-4.yaml down
echo "Stand down R2 platform components"
/opt/docker/docker-compose -f ./docker-compose-3.yaml down
echo "Stand down R2 minimum service components"
/opt/docker/docker-compose -f ./docker-compose-2.yaml down
echo "Stand down R2 shared platform components"
/opt/docker/docker-compose -f ./docker-compose-1.yaml down
echo "Teardown done"
