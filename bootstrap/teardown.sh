#!/bin/bash
#
# ============LICENSE_START==========================================
# ===================================================================
# Copyright © 2017 AT&T Intellectual Property. All rights reserved.
# ===================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END============================================
#
# ECOMP and OpenECOMP are trademarks
# and service marks of AT&T Intellectual Property.
#
set -x
set -e

rm -f /tmp/ready_to_exit

source ./dcaeinstall/bin/activate
cd ./consul
cfy status
set +e
cfy uninstall -d cdapbroker
cfy uninstall -d cdap7
cfy uninstall -d policy_handler
cfy uninstall -d DeploymentHandler
cfy uninstall -d PlatformServicesInventory
cfy uninstall -d config_binding_service
cfy executions start -w uninstall -d DockerComponent
cfy deployments delete -d DockerComponent
cfy uninstall -d DockerPlatform
cfy uninstall -d consul
cd ..
cfy local uninstall

touch /tmp/ready_to_exit
